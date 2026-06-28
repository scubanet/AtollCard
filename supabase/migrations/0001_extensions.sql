-- pgcrypto: gen_random_uuid(); pgtap: database tests
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pgtap with schema extensions;
