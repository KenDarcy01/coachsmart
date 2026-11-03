-- One-off (Ken, 2026-11-03): net._http_response held a few hundred rows of
-- pg_net call results but took 196 MB on disk (old bloat; pg_net expires rows
-- after 6 hours anyway). TRUNCATE gives the space back straight away. Nothing
-- in the app reads this table; only a live-alert diagnostic glances at it.
TRUNCATE net._http_response;
