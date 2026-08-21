-- Capture get_event_payment_details_v2 from Supabase into version control.
-- Returns confirmed payments for an event, joining payer (users) and member names.

CREATE OR REPLACE FUNCTION public.get_event_payment_details_v2(p_event_id bigint)
RETURNS TABLE(
  user_full_name             text,
  member_full_name           text,
  payment_date               text,
  payment_id                 bigint,
  event_id                   bigint,
  user_id                    uuid,
  event_title                text,
  stripe_session_id          text,
  payment_status             text,
  amount_paid                integer,
  stripe_payment_intent_id   text,
  stripe_checkout_url        text,
  fee_amount                 smallint,
  net_amount                 smallint,
  tax_amount                 smallint,
  gross_amount               smallint,
  member_id                  bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
    SELECT
        u.first_name || ' ' || u.last_name AS user_full_name,
        m.first_name || ' ' || m.last_name AS member_full_name,
        TO_CHAR(eump.created_at, 'DD Mon YYYY') AS payment_date,
        eump.payment_id,
        eump.event_id,
        eump.user_id,
        eump.event_title,
        eump.stripe_session_id,
        eump.payment_status,
        eump.amount_paid,
        eump.stripe_payment_intent_id,
        eump.stripe_checkout_url,
        eump.fee_amount,
        eump.net_amount,
        eump.tax_amount,
        eump.gross_amount,
        eump.member_id
    FROM public.event_user_member_payment eump
    JOIN public.users u ON eump.user_id = u.user_id
    JOIN public.members m ON eump.member_id = m.member_id
    WHERE eump.event_id = p_event_id
      AND eump.payment_status = 'confirmed';
$function$;
