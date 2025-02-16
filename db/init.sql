--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2 (Debian 17.2-1.pgdg120+1)
-- Dumped by pg_dump version 17.2 (Debian 17.2-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: create_qr_code_result; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.create_qr_code_result AS (
	short_code text,
	qr_uid uuid
);


ALTER TYPE public.create_qr_code_result OWNER TO admin;

--
-- Name: create_new_user(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.create_new_user() RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    ANON_ID uuid;
BEGIN
    ANON_ID := uuid_generate_v4();
    INSERT INTO temp_users (anon_id, amount_scanned) VALUES(ANON_ID, 0);

    RETURN ANON_ID;

EXCEPTION
    WHEN OTHERS THEN
        -- Log the error details
        RAISE NOTICE 'Error in create_qr_code: %', SQLERRM;
        RAISE;
end;
$$;


ALTER FUNCTION public.create_new_user() OWNER TO admin;

--
-- Name: create_new_user(uuid); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.create_new_user(qr_uid uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    ANON_ID uuid;
BEGIN
    ANON_ID := uuid_generate_v4();
    INSERT INTO temp_users (anon_id, amount_scanned) VALUES(ANON_ID, 0);

    RETURN ANON_ID;

EXCEPTION
    WHEN OTHERS THEN
        -- Log the error details
        RAISE NOTICE 'Error in create_qr_code: %', SQLERRM;
        RAISE;
end;
$$;


ALTER FUNCTION public.create_new_user(qr_uid uuid) OWNER TO admin;

--
-- Name: create_qr_code(text, text); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.create_qr_code(p_uid text, url text) RETURNS public.create_qr_code_result
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_qr_uid uuid;
    v_qr_uid_text text;
    v_filepath text;
    v_short_code text;
    v_result public.create_qr_code_result;
    v_retry_count integer := 0;
    v_max_retries constant integer := 5;
BEGIN
    -- Generate UUID for the QR code
    v_qr_uid := uuid_generate_v4();
    v_qr_uid_text := v_qr_uid::text;

    -- Generate the filepath in the format /XX/XX/UUID.png
    v_filepath := '/qrcodes/' || substring(v_qr_uid_text from 1 for 2) || '/' ||
                  substring(v_qr_uid_text from 3 for 2) || '/' || v_qr_uid_text || '.png';

    -- Loop until we get a unique short code or max retries is reached
    LOOP
        BEGIN
            v_short_code := generate_short_code();

            -- Insert the QR code details into the qr_codes table
            INSERT INTO qr_codes(qr_uid, created_by, embedded_link, short_url, filepath, short_code)
            VALUES (
                       v_qr_uid,
                       P_UID,
                       URL,
                       'http://localhost:3000/findqr/' || v_short_code,
                       v_filepath,
                       v_short_code
                   );

            -- If we get here, the insert succeeded
            EXIT;

        EXCEPTION
            WHEN unique_violation THEN
                -- Check if it was the short_code that caused the violation
                IF v_retry_count >= v_max_retries THEN
                    RAISE EXCEPTION 'Failed to generate unique short code after % attempts', v_max_retries;
                END IF;

                v_retry_count := v_retry_count + 1;
                -- Continue to next iteration of loop to try a new short code
                CONTINUE;
        END;
    END LOOP;

    -- Insert scan aggregates record
    INSERT INTO qr_scan_aggregates(qr_uid, total_scans, last_scanned_at)
    VALUES(v_qr_uid, 0, NULL);

    -- Prepare the result
    v_result.short_code := v_short_code;
    v_result.qr_uid := v_qr_uid;

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        -- Log the error details
        RAISE NOTICE 'Error in create_qr_code: %', SQLERRM;
        RAISE;
END;
$$;


ALTER FUNCTION public.create_qr_code(p_uid text, url text) OWNER TO admin;

--
-- Name: create_qr_code(text, text, text); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.create_qr_code(p_uid text, url text, route text) RETURNS public.create_qr_code_result
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_qr_uid uuid;
    v_qr_uid_text text;
    v_filepath text;
    v_short_code text;
    v_result public.create_qr_code_result;
    v_retry_count integer := 0;
    v_max_retries constant integer := 5;
BEGIN
    -- Generate UUID for the QR code
    v_qr_uid := uuid_generate_v4();
    v_qr_uid_text := v_qr_uid::text;

    -- Generate the filepath in the format /XX/XX/UUID.png
    v_filepath := '/qrcodes/' || substring(v_qr_uid_text from 1 for 2) || '/' ||
                  substring(v_qr_uid_text from 3 for 2) || '/' || v_qr_uid_text || '.png';

    -- Loop until we get a unique short code or max retries is reached
    LOOP
        BEGIN
            v_short_code := generate_short_code();

            -- Insert the QR code details into the qr_codes table
            INSERT INTO qr_codes(qr_uid, created_by, embedded_link, short_url, filepath, short_code, canview)
            VALUES (
                       v_qr_uid,
                       P_UID,
                       URL,
                       ROUTE || v_short_code,
                       v_filepath,
                       v_short_code,
                true
                   );

            -- If we get here, the insert succeeded
            EXIT;

        EXCEPTION
            WHEN unique_violation THEN
                -- Check if it was the short_code that caused the violation
                IF v_retry_count >= v_max_retries THEN
                    RAISE EXCEPTION 'Failed to generate unique short code after % attempts', v_max_retries;
                END IF;

                v_retry_count := v_retry_count + 1;
                -- Continue to next iteration of loop to try a new short code
                CONTINUE;
        END;
    END LOOP;

    -- Insert scan aggregates record
    INSERT INTO qr_scan_aggregates(qr_uid, total_scans, last_scanned_at, total_unique_scans)
    VALUES(v_qr_uid, 0, NULL, 0);

    -- Prepare the result
    v_result.short_code := v_short_code;
    v_result.qr_uid := v_qr_uid;

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        -- Log the error details
        RAISE NOTICE 'Error in create_qr_code: %', SQLERRM;
        RAISE;
END;
$$;


ALTER FUNCTION public.create_qr_code(p_uid text, url text, route text) OWNER TO admin;

--
-- Name: generate_short_code(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.generate_short_code() RETURNS text
    LANGUAGE sql
    AS $$
SELECT substring(md5(random()::text), 1, 6); -- Generates a 6-character hash
$$;


ALTER FUNCTION public.generate_short_code() OWNER TO admin;

--
-- Name: scan_qr_code(uuid, uuid, inet, text, text); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.scan_qr_code(anon_id_x uuid, qr_uid_x uuid, ip_addr_x inet, user_agent_x text, referrer_x text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    NEW_ANON_ID uuid;
    CURRENT_TIMESTAMP_X timestamp := NOW();
    IS_NEW_USER BOOLEAN := FALSE;
BEGIN
    -- Check if anon_id exists, create if not
    IF NOT EXISTS (SELECT 1 FROM temp_users WHERE anon_id = ANON_ID_X) THEN
        NEW_ANON_ID := uuid_generate_v4();
        INSERT INTO temp_users (anon_id, amount_scanned, last_scanned_at)
        VALUES (NEW_ANON_ID, 1, CURRENT_TIMESTAMP_X);
        IS_NEW_USER := TRUE;
    ELSE
        -- Also want to update the aggregate unique id
        IF NOT EXISTS(SELECT 1 FROM qr_scans WHERE anon_id = ANON_ID_X) THEN
            UPDATE qr_scan_aggregates SET total_unique_scans = qr_scan_aggregates.total_unique_scans + 1  WHERE qr_uid = QR_UID_X;
        end if;
        NEW_ANON_ID := ANON_ID_X;
        -- Update temp_users scan count & last scanned timestamp
        UPDATE temp_users
        SET amount_scanned = amount_scanned + 1,
            last_scanned_at = CURRENT_TIMESTAMP_X
        WHERE anon_id = NEW_ANON_ID;
    END IF;

    -- Insert new scan record into qr_scans
    INSERT INTO qr_scans (anon_id, qr_uid, scanned_at, ip_address, user_agent, referrer)
    VALUES (NEW_ANON_ID, QR_UID_X, CURRENT_TIMESTAMP_X, COALESCE(IP_ADDR_X, '0.0.0.0'::INET), USER_AGENT_X, REFERRER_X); -- ✅ Fix: Ensures valid IP

    -- Update qr_scan_aggregates (increment total_scans, update last_scanned_at)
    INSERT INTO qr_scan_aggregates (qr_uid, total_scans, last_scanned_at)
    VALUES (QR_UID_X, 1, CURRENT_TIMESTAMP_X)
    ON CONFLICT (qr_uid) DO UPDATE
        SET total_scans = qr_scan_aggregates.total_scans + 1,
            last_scanned_at = CURRENT_TIMESTAMP_X;

    IF IS_NEW_USER THEN
        RETURN NEW_ANON_ID::text;
    ELSE
        RETURN 'Scan recorded successfully';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error message
        RAISE NOTICE 'Error in scan_qr_code: %', SQLERRM;
        RETURN 'Error occurred while scanning QR code';
END;
$$;


ALTER FUNCTION public.scan_qr_code(anon_id_x uuid, qr_uid_x uuid, ip_addr_x inet, user_agent_x text, referrer_x text) OWNER TO admin;

--
-- Name: scan_qr_code(uuid, uuid, inet, text, text, text, text, numeric, numeric); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.scan_qr_code(anon_id_x uuid, qr_uid_x uuid, ip_addr_x inet, user_agent_x text, referrer_x text, city_x text, state_x text, lat_x numeric, lon_x numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    NEW_ANON_ID uuid;
    CURRENT_TIMESTAMP_X timestamp := NOW();
    IS_NEW_USER BOOLEAN := FALSE;
BEGIN
    -- Check if anon_id exists, create if not
    IF NOT EXISTS (SELECT 1 FROM temp_users WHERE anon_id = ANON_ID_X) THEN
        NEW_ANON_ID := uuid_generate_v4();
        INSERT INTO temp_users (anon_id, amount_scanned, last_scanned_at)
        VALUES (NEW_ANON_ID, 1, CURRENT_TIMESTAMP_X);
        IS_NEW_USER := TRUE;
    ELSE
        -- Also want to update the aggregate unique id
        IF NOT EXISTS(SELECT 1 FROM qr_scans WHERE anon_id = ANON_ID_X) THEN
            UPDATE qr_scan_aggregates SET total_unique_scans = qr_scan_aggregates.total_unique_scans + 1  WHERE qr_uid = QR_UID_X;
        end if;
        NEW_ANON_ID := ANON_ID_X;
        -- Update temp_users scan count & last scanned timestamp
        UPDATE temp_users
        SET amount_scanned = amount_scanned + 1,
            last_scanned_at = CURRENT_TIMESTAMP_X
        WHERE anon_id = NEW_ANON_ID;
    END IF;

    -- Insert new scan record into qr_scans
    INSERT INTO qr_scans (anon_id, qr_uid, scanned_at, ip_address, user_agent, referrer, city, state, lat, lon)
    VALUES (NEW_ANON_ID, QR_UID_X, CURRENT_TIMESTAMP_X, COALESCE(IP_ADDR_X, '0.0.0.0'::INET), USER_AGENT_X, REFERRER_X, CITY_X, STATE_X, LAT_X, LON_X);

    -- Update qr_scan_aggregates (increment total_scans, update last_scanned_at)
    INSERT INTO qr_scan_aggregates (qr_uid, total_scans, last_scanned_at)
    VALUES (QR_UID_X, 1, CURRENT_TIMESTAMP_X)
    ON CONFLICT (qr_uid) DO UPDATE
        SET total_scans = qr_scan_aggregates.total_scans + 1,
            last_scanned_at = CURRENT_TIMESTAMP_X;

    IF IS_NEW_USER THEN
        RETURN NEW_ANON_ID::text;
    ELSE
        RETURN 'Scan recorded successfully';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error message
        RAISE NOTICE 'Error in scan_qr_code: %', SQLERRM;
        RETURN 'Error occurred while scanning QR code';
END;
$$;


ALTER FUNCTION public.scan_qr_code(anon_id_x uuid, qr_uid_x uuid, ip_addr_x inet, user_agent_x text, referrer_x text, city_x text, state_x text, lat_x numeric, lon_x numeric) OWNER TO admin;

--
-- Name: scan_qr_code(uuid, uuid, inet, text, text, text, text, numeric, numeric, text); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.scan_qr_code(anon_id_x uuid, qr_uid_x uuid, ip_addr_x inet, user_agent_x text, referrer_x text, city_x text, state_x text, lat_x numeric, lon_x numeric, os_x text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    NEW_ANON_ID uuid;
    CURRENT_TIMESTAMP_X timestamp := NOW();
    IS_NEW_USER BOOLEAN := FALSE;
BEGIN
    -- Check if anon_id exists, create if not
    IF NOT EXISTS (SELECT 1 FROM temp_users WHERE anon_id = ANON_ID_X) THEN
        NEW_ANON_ID := uuid_generate_v4();
        INSERT INTO temp_users (anon_id, amount_scanned, last_scanned_at)
        VALUES (NEW_ANON_ID, 1, CURRENT_TIMESTAMP_X);
        IS_NEW_USER := TRUE;
    ELSE
        -- Also want to update the aggregate unique id
        IF NOT EXISTS(SELECT 1 FROM qr_scans WHERE anon_id = ANON_ID_X) THEN
            UPDATE qr_scan_aggregates SET total_unique_scans = qr_scan_aggregates.total_unique_scans + 1  WHERE qr_uid = QR_UID_X;
        end if;
        NEW_ANON_ID := ANON_ID_X;
        -- Update temp_users scan count & last scanned timestamp
        UPDATE temp_users
        SET amount_scanned = amount_scanned + 1,
            last_scanned_at = CURRENT_TIMESTAMP_X
        WHERE anon_id = NEW_ANON_ID;
    END IF;

    -- Insert new scan record into qr_scans
    INSERT INTO qr_scans (anon_id, qr_uid, scanned_at, ip_address, user_agent, referrer, city, state, lat, lon, os)
    VALUES (NEW_ANON_ID, QR_UID_X, CURRENT_TIMESTAMP_X, COALESCE(IP_ADDR_X, '0.0.0.0'::INET), USER_AGENT_X, REFERRER_X, CITY_X, STATE_X, LAT_X, LON_X, OS_X);

    -- Update qr_scan_aggregates (increment total_scans, update last_scanned_at)
    INSERT INTO qr_scan_aggregates (qr_uid, total_scans, last_scanned_at)
    VALUES (QR_UID_X, 1, CURRENT_TIMESTAMP_X)
    ON CONFLICT (qr_uid) DO UPDATE
        SET total_scans = qr_scan_aggregates.total_scans + 1,
            last_scanned_at = CURRENT_TIMESTAMP_X;

    IF IS_NEW_USER THEN
        RETURN NEW_ANON_ID::text;
    ELSE
        RETURN 'Scan recorded successfully';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error message
        RAISE NOTICE 'Error in scan_qr_code: %', SQLERRM;
        RETURN 'Error occurred while scanning QR code';
END;
$$;


ALTER FUNCTION public.scan_qr_code(anon_id_x uuid, qr_uid_x uuid, ip_addr_x inet, user_agent_x text, referrer_x text, city_x text, state_x text, lat_x numeric, lon_x numeric, os_x text) OWNER TO admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_info; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.admin_info (
    kudos integer
);


ALTER TABLE public.admin_info OWNER TO admin;

--
-- Name: qr_codes; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.qr_codes (
    qr_uid uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_by character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    embedded_link text NOT NULL,
    short_url character varying(255) NOT NULL,
    filepath character varying(255),
    short_code text,
    canview boolean
);


ALTER TABLE public.qr_codes OWNER TO admin;

--
-- Name: qr_scan_aggregates; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.qr_scan_aggregates (
    qr_uid uuid NOT NULL,
    total_scans integer DEFAULT 0,
    last_scanned_at timestamp without time zone,
    total_unique_scans integer
);


ALTER TABLE public.qr_scan_aggregates OWNER TO admin;

--
-- Name: qr_scans; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.qr_scans (
    scan_id integer NOT NULL,
    qr_uid uuid,
    ip_address inet NOT NULL,
    user_agent text NOT NULL,
    referrer text,
    scanned_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    anon_id uuid,
    city character varying(255),
    state character varying(255),
    lat numeric,
    lon numeric,
    os text
);


ALTER TABLE public.qr_scans OWNER TO admin;

--
-- Name: qr_scans_scan_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.qr_scans_scan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.qr_scans_scan_id_seq OWNER TO admin;

--
-- Name: qr_scans_scan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.qr_scans_scan_id_seq OWNED BY public.qr_scans.scan_id;


--
-- Name: temp_users; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.temp_users (
    anon_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    amount_scanned integer DEFAULT 1,
    last_scanned_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.temp_users OWNER TO admin;

--
-- Name: users; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.users (
    google_uid character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    email character varying(255),
    username character varying(255),
    profile_picture character varying(255)
);


ALTER TABLE public.users OWNER TO admin;

--
-- Name: qr_scans scan_id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_scans ALTER COLUMN scan_id SET DEFAULT nextval('public.qr_scans_scan_id_seq'::regclass);


--
-- Data for Name: admin_info; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.admin_info (kudos) FROM stdin;
3
\.


--
-- Data for Name: qr_codes; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.qr_codes (qr_uid, created_by, created_at, embedded_link, short_url, filepath, short_code, canview) FROM stdin;
7dcbe1ed-d379-4bc6-98d0-9a580ce820e9	107658376580219149604	2025-02-08 18:51:30.105329	test1232332.com	http://localhost:3000/findqr/db4a5f	/qrcodes/7d/cb/7dcbe1ed-d379-4bc6-98d0-9a580ce820e9.png	db4a5f	f
fbbc4938-e568-48b6-b799-cdc70bf491e8	107658376580219149604	2025-02-08 16:56:37.683064	mel.com	http://localhost:3000/findqr/67a799	/qrcodes/fb/bc/fbbc4938-e568-48b6-b799-cdc70bf491e8.png	67a799	f
c3b6c2f1-f39e-4b2d-afde-08d49095906f	107658376580219149604	2025-02-08 18:50:44.776703	test123.com	http://localhost:3000/findqr/ac883d	/qrcodes/c3/b6/c3b6c2f1-f39e-4b2d-afde-08d49095906f.png	ac883d	\N
840989ed-0144-42d1-87b5-e16a843f1ab4	107658376580219149604	2025-02-08 16:01:31.651766	jwaguirre.xyz	http://localhost:3000/findqr/c6adc7	/qrcodes/84/09/840989ed-0144-42d1-87b5-e16a843f1ab4.png	c6adc7	f
da4b7b8a-03f2-46b6-a759-f5619a0e6699	107658376580219149604	2025-02-08 16:08:06.189623	google.com	http://localhost:3000/findqr/f723c8	/qrcodes/da/4b/da4b7b8a-03f2-46b6-a759-f5619a0e6699.png	f723c8	f
05b3dc3a-20bf-4b80-a1d4-df25dacd5b9c	107658376580219149604	2025-02-08 18:55:40.32037	https://jwaguirre.xyz	http://localhost:3000/findqr/8cb536	/qrcodes/05/b3/05b3dc3a-20bf-4b80-a1d4-df25dacd5b9c.png	8cb536	f
b4d19593-2a85-4349-be6e-c2c5dd216c44	107658376580219149604	2025-02-10 15:16:16.015015	bruh.com	http://localhost:3000/findqr/7201e1	/qrcodes/b4/d1/b4d19593-2a85-4349-be6e-c2c5dd216c44.png	7201e1	f
6ec30c8f-5bd9-4e29-aece-e0818ec38d50	107658376580219149604	2025-02-08 22:40:06.537145	xyz.com	http://localhost:3000/findqr/1a3da9	/qrcodes/6e/c3/6ec30c8f-5bd9-4e29-aece-e0818ec38d50.png	1a3da9	f
af133b37-e51c-453e-9b96-451016004bb7	107658376580219149604	2025-02-08 21:26:19.006348	jwaguirre.xyz	http://localhost:3000/findqr/b7d9eb	/qrcodes/af/13/af133b37-e51c-453e-9b96-451016004bb7.png	b7d9eb	f
daf4e020-a728-488a-a2ad-accdfc922e34	107658376580219149604	2025-02-12 15:20:23.171054	https://jwaguirre.xyz	http://168.5.52.61:3000/findqr/4f0b5e	/qrcodes/da/f4/daf4e020-a728-488a-a2ad-accdfc922e34.png	4f0b5e	f
479ddc7a-310b-4c9a-a2c3-7502eaa2f5f5	107658376580219149604	2025-02-09 00:39:01.005048	https://jwaguirre.xyz	http://localhost:3000/findqr/d2e549	/qrcodes/47/9d/479ddc7a-310b-4c9a-a2c3-7502eaa2f5f5.png	d2e549	f
91420231-a854-4e46-b78d-7d49d302b4c3	107658376580219149604	2025-02-12 06:36:58.930348	xys.com	http://localhost:3000/findqr/c72019	/qrcodes/91/42/91420231-a854-4e46-b78d-7d49d302b4c3.png	c72019	f
6555ddb1-9b58-4fb9-80e1-113b8df91a73	107658376580219149604	2025-02-08 22:55:38.530327	tsets.com	http://localhost:3000/findqr/7ce2a9	/qrcodes/65/55/6555ddb1-9b58-4fb9-80e1-113b8df91a73.png	7ce2a9	f
59939f16-f310-4f0d-91ce-b9049ed990ab	107658376580219149604	2025-02-12 19:41:06.839304	https://jwaguirre.xyz	http://168.5.52.61:3000/findqr/e323ee	/qrcodes/59/93/59939f16-f310-4f0d-91ce-b9049ed990ab.png	e323ee	f
5e9a5f06-39b2-408c-877f-fb43e68cf050	107658376580219149604	2025-02-13 14:51:38.951479	https://jwaguirre.xyz	http://168.5.52.61:3000/findqr/80d24b	/qrcodes/5e/9a/5e9a5f06-39b2-408c-877f-fb43e68cf050.png	80d24b	f
2908996e-80b6-44de-a030-8f8b3bf16777	107658376580219149604	2025-02-13 14:57:04.034774	https://jwaguirre.xyz	http://10.244.245.129:3000/findqr/cafe80	/qrcodes/29/08/2908996e-80b6-44de-a030-8f8b3bf16777.png	cafe80	t
3a7479ac-16c7-4018-8d2b-508b8cadadd5	107658376580219149604	2025-02-13 22:40:04.220654	https://jwaguirre.xyz	http://10.244.245.129:3000/findqr/2eb699	/qrcodes/3a/74/3a7479ac-16c7-4018-8d2b-508b8cadadd5.png	2eb699	t
\.


--
-- Data for Name: qr_scan_aggregates; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.qr_scan_aggregates (qr_uid, total_scans, last_scanned_at, total_unique_scans) FROM stdin;
2908996e-80b6-44de-a030-8f8b3bf16777	2	2025-02-13 15:08:53.388962	1
3a7479ac-16c7-4018-8d2b-508b8cadadd5	1	2025-02-13 22:40:17.180081	1
da4b7b8a-03f2-46b6-a759-f5619a0e6699	1	2025-02-08 17:55:30.456708	\N
fbbc4938-e568-48b6-b799-cdc70bf491e8	1	2025-02-08 17:57:03.431502	\N
c3b6c2f1-f39e-4b2d-afde-08d49095906f	0	\N	\N
7dcbe1ed-d379-4bc6-98d0-9a580ce820e9	0	\N	\N
05b3dc3a-20bf-4b80-a1d4-df25dacd5b9c	1	2025-02-08 18:55:53.870403	\N
af133b37-e51c-453e-9b96-451016004bb7	0	\N	\N
6ec30c8f-5bd9-4e29-aece-e0818ec38d50	0	\N	\N
6555ddb1-9b58-4fb9-80e1-113b8df91a73	1	2025-02-09 00:37:28.157953	\N
479ddc7a-310b-4c9a-a2c3-7502eaa2f5f5	4	2025-02-09 02:01:32.069167	1
b4d19593-2a85-4349-be6e-c2c5dd216c44	0	\N	0
91420231-a854-4e46-b78d-7d49d302b4c3	0	\N	0
840989ed-0144-42d1-87b5-e16a843f1ab4	4	2025-02-12 15:33:44.192587	\N
daf4e020-a728-488a-a2ad-accdfc922e34	5	2025-02-12 16:05:27.289946	1
59939f16-f310-4f0d-91ce-b9049ed990ab	1	2025-02-12 19:46:11.262477	0
5e9a5f06-39b2-408c-877f-fb43e68cf050	0	\N	0
\.


--
-- Data for Name: qr_scans; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.qr_scans (scan_id, qr_uid, ip_address, user_agent, referrer, scanned_at, anon_id, city, state, lat, lon, os) FROM stdin;
1	840989ed-0144-42d1-87b5-e16a843f1ab4	::1	Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36	None	2025-02-08 17:51:51.998729	39a8fcf1-41d5-4570-8527-460024aee526	\N	\N	\N	\N	\N
2	840989ed-0144-42d1-87b5-e16a843f1ab4	::1	Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36	None	2025-02-08 17:54:54.200323	39a8fcf1-41d5-4570-8527-460024aee526	\N	\N	\N	\N	\N
3	da4b7b8a-03f2-46b6-a759-f5619a0e6699	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-08 17:55:30.456708	39a8fcf1-41d5-4570-8527-460024aee526	\N	\N	\N	\N	\N
4	fbbc4938-e568-48b6-b799-cdc70bf491e8	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-08 17:57:03.431502	a8395d13-fce5-4074-aec9-2674eeff4aa9	\N	\N	\N	\N	\N
5	05b3dc3a-20bf-4b80-a1d4-df25dacd5b9c	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-08 18:55:53.870403	a8395d13-fce5-4074-aec9-2674eeff4aa9	\N	\N	\N	\N	\N
6	6555ddb1-9b58-4fb9-80e1-113b8df91a73	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-09 00:37:28.157953	a8395d13-fce5-4074-aec9-2674eeff4aa9	\N	\N	\N	\N	\N
7	479ddc7a-310b-4c9a-a2c3-7502eaa2f5f5	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-09 00:40:05.348565	99939b60-a402-487c-8ec1-d73d7c41c91b	\N	\N	\N	\N	\N
8	479ddc7a-310b-4c9a-a2c3-7502eaa2f5f5	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-09 00:40:17.492941	99939b60-a402-487c-8ec1-d73d7c41c91b	\N	\N	\N	\N	\N
9	479ddc7a-310b-4c9a-a2c3-7502eaa2f5f5	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-09 01:01:40.058665	99939b60-a402-487c-8ec1-d73d7c41c91b	\N	\N	\N	\N	\N
10	479ddc7a-310b-4c9a-a2c3-7502eaa2f5f5	::1	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36	None	2025-02-09 02:01:32.069167	99939b60-a402-487c-8ec1-d73d7c41c91b	\N	\N	\N	\N	\N
11	daf4e020-a728-488a-a2ad-accdfc922e34	::ffff:168.5.53.130	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-12 15:21:40.242987	275f8be9-f249-4c9c-9175-16ec320dec1b	\N	\N	\N	\N	\N
12	840989ed-0144-42d1-87b5-e16a843f1ab4	::1	Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36	None	2025-02-12 15:33:19.956957	39a8fcf1-41d5-4570-8527-460024aee526	\N	\N	\N	\N	\N
13	840989ed-0144-42d1-87b5-e16a843f1ab4	::1	Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36	None	2025-02-12 15:33:44.192587	39a8fcf1-41d5-4570-8527-460024aee526	Houston	\N	\N	\N	\N
14	daf4e020-a728-488a-a2ad-accdfc922e34	::ffff:168.5.53.130	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-12 15:37:03.505728	275f8be9-f249-4c9c-9175-16ec320dec1b	\N	\N	\N	\N	\N
15	daf4e020-a728-488a-a2ad-accdfc922e34	::ffff:168.5.53.130	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-12 15:38:59.863756	275f8be9-f249-4c9c-9175-16ec320dec1b	\N	\N	\N	\N	\N
16	daf4e020-a728-488a-a2ad-accdfc922e34	::ffff:168.5.53.130	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-12 15:41:58.731986	275f8be9-f249-4c9c-9175-16ec320dec1b	Houston	Texas	29.7056	-95.402	\N
17	daf4e020-a728-488a-a2ad-accdfc922e34	::ffff:168.5.53.130	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-12 16:05:27.289946	275f8be9-f249-4c9c-9175-16ec320dec1b	Houston	Texas	29.7056	-95.402	iOS
18	59939f16-f310-4f0d-91ce-b9049ed990ab	::ffff:168.5.53.130	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-12 19:46:11.262477	275f8be9-f249-4c9c-9175-16ec320dec1b	Houston	Texas	29.7056	-95.402	iOS
19	2908996e-80b6-44de-a030-8f8b3bf16777	::ffff:10.244.245.140	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-13 15:06:20.301521	e065e093-3403-4847-ad03-128148c02659	\N	\N	\N	\N	iOS
20	2908996e-80b6-44de-a030-8f8b3bf16777	::ffff:10.244.245.140	Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1	None	2025-02-13 15:08:53.388962	e065e093-3403-4847-ad03-128148c02659	\N	\N	\N	\N	iOS
21	3a7479ac-16c7-4018-8d2b-508b8cadadd5	::ffff:10.244.245.147	Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15	None	2025-02-13 22:40:17.180081	9ff31775-8c3c-4435-96c9-7cf03f5fe7ea	\N	\N	\N	\N	macOS
\.


--
-- Data for Name: temp_users; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.temp_users (anon_id, amount_scanned, last_scanned_at) FROM stdin;
a8395d13-fce5-4074-aec9-2674eeff4aa9	3	2025-02-09 00:37:28.157953
99939b60-a402-487c-8ec1-d73d7c41c91b	4	2025-02-09 02:01:32.069167
39a8fcf1-41d5-4570-8527-460024aee526	5	2025-02-12 15:33:44.192587
275f8be9-f249-4c9c-9175-16ec320dec1b	6	2025-02-12 19:46:11.262477
e065e093-3403-4847-ad03-128148c02659	2	2025-02-13 15:08:53.388962
9ff31775-8c3c-4435-96c9-7cf03f5fe7ea	1	2025-02-13 22:40:17.180081
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.users (google_uid, created_at, email, username, profile_picture) FROM stdin;
107658376580219149604	2025-02-07 22:03:15.746043	jw.aguirre23@gmail.com	Justin Aguirre	https://lh3.googleusercontent.com/a/ACg8ocLlbOFfiGQOpTATx58tUY9_ElAjYo3_pm0KooAHuCS_rhWj-w=s96-c
\.


--
-- Name: qr_scans_scan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.qr_scans_scan_id_seq', 21, true);


--
-- Name: qr_codes qr_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_codes
    ADD CONSTRAINT qr_codes_pkey PRIMARY KEY (qr_uid);


--
-- Name: qr_codes qr_codes_short_code_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_codes
    ADD CONSTRAINT qr_codes_short_code_key UNIQUE (short_code);


--
-- Name: qr_codes qr_codes_short_url_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_codes
    ADD CONSTRAINT qr_codes_short_url_key UNIQUE (short_url);


--
-- Name: qr_scan_aggregates qr_scan_aggregates_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_scan_aggregates
    ADD CONSTRAINT qr_scan_aggregates_pkey PRIMARY KEY (qr_uid);


--
-- Name: qr_scans qr_scans_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_scans
    ADD CONSTRAINT qr_scans_pkey PRIMARY KEY (scan_id);


--
-- Name: temp_users temp_users_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.temp_users
    ADD CONSTRAINT temp_users_pkey PRIMARY KEY (anon_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (google_uid);


--
-- Name: qr_codes qr_codes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_codes
    ADD CONSTRAINT qr_codes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(google_uid) ON DELETE CASCADE;


--
-- Name: qr_scan_aggregates qr_scan_aggregates_qr_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_scan_aggregates
    ADD CONSTRAINT qr_scan_aggregates_qr_uid_fkey FOREIGN KEY (qr_uid) REFERENCES public.qr_codes(qr_uid) ON DELETE CASCADE;


--
-- Name: qr_scans qr_scans_qr_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.qr_scans
    ADD CONSTRAINT qr_scans_qr_uid_fkey FOREIGN KEY (qr_uid) REFERENCES public.qr_codes(qr_uid) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

