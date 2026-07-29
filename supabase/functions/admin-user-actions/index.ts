// Supabase Edge Function: admin-user-actions
//
// Covers two admin-only, service-role-privileged actions that the app's anon-key client
// cannot perform on its own:
//   - reset_password: set a random password for an existing user + flag must_change_password
//   - create_user:    create a new auth.users account + matching profiles row, with a random
//                      temp password + must_change_password=true
//
// The caller's identity and admin status are verified using their own JWT (passed through
// as the Authorization header by supabase-js's functions.invoke) before any privileged
// action runs. The service-role key is only ever used inside this server-side function,
// never sent to the browser.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function randomPassword(len = 12) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const bytes = new Uint8Array(len);
  crypto.getRandomValues(bytes);
  let out = "";
  for (let i = 0; i < len; i++) out += chars[bytes[i] % chars.length];
  return out;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing Authorization header");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Client scoped to the calling user's own JWT — used only to verify identity + admin
    // status via RLS-protected reads, never for the privileged writes below.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !user) throw new Error("Not authenticated");

    const { data: callerProfile, error: profErr } = await callerClient
      .from("profiles")
      .select("is_admin,is_active")
      .eq("id", user.id)
      .single();
    if (profErr || !callerProfile) throw new Error("Could not verify caller profile");
    if (!callerProfile.is_admin || !callerProfile.is_active) {
      throw new Error("Admin access required");
    }

    const body = await req.json();
    const { action } = body;

    // Privileged client — service-role key never leaves this server-side function.
    const admin = createClient(supabaseUrl, serviceKey);

    if (action === "reset_password") {
      const { userId } = body;
      if (!userId) throw new Error("userId is required");
      const newPassword = randomPassword();
      const { error } = await admin.auth.admin.updateUserById(userId, { password: newPassword });
      if (error) throw error;
      const { error: flagErr } = await admin
        .from("profiles")
        .update({ must_change_password: true })
        .eq("id", userId);
      if (flagErr) throw flagErr;
      return jsonResponse({ password: newPassword });
    }

    if (action === "create_user") {
      const {
        email, firstName, lastName, employeeId, positionId, supervisorId, hireDate,
        isAdmin, isReportsViewer, formTrainer, formIDQA, formCQA, dashScope,
      } = body;
      if (!email || !firstName || !lastName) {
        throw new Error("email, firstName, and lastName are required");
      }
      const newPassword = randomPassword();
      const { data: created, error: createErr } = await admin.auth.admin.createUser({
        email,
        password: newPassword,
        email_confirm: true,
      });
      if (createErr) throw createErr;
      const newId = created.user.id;

      const { error: insertErr } = await admin.from("profiles").insert({
        id: newId,
        email,
        first_name: firstName,
        last_name: lastName,
        employee_id: employeeId || null,
        position_id: positionId || null,
        supervisor_id: supervisorId || null,
        hire_date: hireDate || null,
        is_active: true,
        is_admin: !!isAdmin,
        is_reports_viewer: !!isReportsViewer,
        form_trainer: !!formTrainer,
        form_idqa: !!formIDQA,
        form_cqa: !!formCQA,
        dash_scope: dashScope || "team",
        must_change_password: true,
      });
      if (insertErr) {
        // Roll back the orphaned auth user so a failed profile insert doesn't leave a
        // half-created account behind.
        await admin.auth.admin.deleteUser(newId);
        throw insertErr;
      }

      return jsonResponse({ password: newPassword, id: newId });
    }

    throw new Error(`Unknown action: ${action}`);
  } catch (e) {
    return jsonResponse({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
