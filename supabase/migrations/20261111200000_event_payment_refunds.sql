-- Refunds for event payments from the app (Ken, 2026-11-11, thread "Check
-- payments on the v3 screens"). The refund-event-payment edge function
-- refunds one player's share through Stripe and sets the row to 'refunded'.
-- Every reader already counts only 'confirmed' rows, so a refunded player
-- goes back to Not paid and drops out of the totals.

ALTER TABLE public.event_user_member_payment
    ADD COLUMN IF NOT EXISTS refund_id   text,
    ADD COLUMN IF NOT EXISTS refunded_at timestamptz,
    ADD COLUMN IF NOT EXISTS refunded_by uuid;

-- Refunded payments for an event, for the v3 Payments page. Team admins only.
CREATE OR REPLACE FUNCTION public.get_event_refunds(p_event_id bigint)
RETURNS TABLE(payment_id bigint, member_id bigint, member_full_name text,
              user_full_name text, amount_paid integer, refunded_at timestamptz)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
    SELECT eump.payment_id,
           eump.member_id,
           m.first_name || ' ' || m.last_name,
           u.first_name || ' ' || u.last_name,
           eump.amount_paid,
           eump.refunded_at
    FROM public.event_user_member_payment eump
    JOIN public.members m ON m.member_id = eump.member_id
    LEFT JOIN public.users u ON u.user_id = eump.user_id
    WHERE eump.event_id = p_event_id
      AND eump.payment_status = 'refunded'
      AND public.is_event_admin(p_event_id)
    ORDER BY eump.refunded_at DESC NULLS LAST;
$function$;
