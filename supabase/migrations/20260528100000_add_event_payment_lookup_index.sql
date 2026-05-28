CREATE INDEX idx_event_payment_confirmed_lookup
ON public.event_user_member_payment(event_id, user_id)
WHERE payment_status = 'confirmed';
