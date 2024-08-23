\c duckhunt

CREATE OR REPLACE FUNCTION start(game_level INTEGER DEFAULT 1) RETURNS VOID AS $$
DECLARE
    game_id INTEGER;
BEGIN
    IF (current_setting('game.id', true) IS NULL OR current_setting('game.id', true) = '0') THEN
        RAISE NOTICE '🦆 Starting a new game 🦆';

        PERFORM set_config('game.template', '                               x
                               1
                               2
                               3
                               4
                               5
 ===#                          6
 # ===                         7
  #***                         8
#==+##+==                      9
 ## *=+#                       a
  ###                          b
  ##                   #==     c
=-==##++* *====** *=====##*##**#
+=======+=======================
+=======+=======================', false);
        PERFORM set_config('game.board', current_setting('game.template', true), false);
        PERFORM set_config('game.level', game_level::text, false);
        PERFORM set_config('game.gunx', '9', false);
        PERFORM set_config('game.guny', '8', false);
        PERFORM place_duck();

        INSERT INTO duckhunt (game_level, shots_fired, ducks) values (
            game_level, 0, ARRAY[]::INTEGER[]
        ) RETURNING id INTO game_id;
        RAISE INFO 'Game ID: %', game_id;
        PERFORM set_config('game.id', game_id::text, false);
        PERFORM next_direction();

        PERFORM show();
    ELSE
        RAISE EXCEPTION 'Game already in progress, stop it with stop() first';
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION place_duck() RETURNS VOID AS $$
BEGIN
    PERFORM set_config('game.direction', '2', false);
    PERFORM set_config('game.duckx', (floor(random()*16)+1)::text, false);
    PERFORM set_config('game.ducky', '16', false);
    PERFORM set_config('game.bullets', '3', false);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION stop() RETURNS VOID AS $$
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        RAISE NOTICE 'Stopping game ID %!', current_setting('game.id', true);
        PERFORM set_config('game.id', '0', false);
    END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION show(outcome INT DEFAULT -1, ducks TEXT[] DEFAULT ARRAY[]::TEXT[]) RETURNS VOID AS $$
DECLARE
notice_message TEXT;
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        IF outcome = 1 THEN
            notice_message := '    💥🦆 NICE SHOOTING! 🦆💥';
        ELSIF outcome = 2 THEN
            notice_message := '       🤡🐶 FAILED! 🐶🤡';
        ELSIF outcome = 0 THEN
            notice_message := '       🫥🔫 MISSED! 🔫🫥';
        ELSIF outcome = 3 THEN
            notice_message := '        ✨ GAME OVER ✨';
        ELSE
            notice_message := '     🐕 START SHOOTING! 🐕';
        END IF;

        PERFORM set_config('game.board', current_setting('game.template', true), false);
        PERFORM place(current_setting('game.duckx', true)::INT, current_setting('game.ducky', true)::INT, '🦆', 1);
        PERFORM place(current_setting('game.gunx', true)::INT, current_setting('game.guny', true)::INT, '█ ', 1);

        RAISE INFO E'         🚀%   💥%    🔼%
________________________________
%
________________________________
 %

%', current_setting('game.level', true), current_setting('game.bullets', true), ('{"←","↑","→","↓","↖","↗","↘","↙"}'::text[])[(current_setting('game.direction', true)::int)], current_setting('game.board', true), ARRAY_TO_STRING(ducks, ' '), notice_message;

    END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION place(x int, y int, obj TEXT, repl_length int)
RETURNS VOID AS $$
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        IF (x < 1 OR x > 16 OR y < 1 OR y > 16) THEN
            RAISE EXCEPTION 'Coordinates out of bounds';
        END IF;

        PERFORM set_config('game.board', 
            (WITH board AS (
                WITH template AS (
                SELECT array_to_string(string_to_array(current_setting('game.board', true), E'\n'), E'') AS text
                )
                SELECT substring(text, 1, ((y-1)*32+(x-1)*2)) || obj || substring(text, ((y-1)*32+x*2+repl_length)) AS modified_text
                FROM template
            )
            SELECT string_agg(chunk, E'\n') FROM (
            SELECT substring(modified_text, (n-1)*32+1, 32) AS chunk
            FROM board, generate_series(1, ceil(length(modified_text)/32.0)::int) n
            ) AS chunks),
        false);
    END IF;
END
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION next_direction() RETURNS VOID AS $$
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        PERFORM set_config('game.direction', (
            WITH possible_directions AS (
                SELECT ARRAY_REMOVE(ARRAY[
                    CASE WHEN current_setting('game.duckx', true)::int > 1 THEN 1 ELSE NULL END,  -- move left
                    CASE WHEN current_setting('game.ducky', true)::int > 1 THEN 2 ELSE NULL END,  -- move up
                    CASE WHEN current_setting('game.duckx', true)::int < 16 THEN 3 ELSE NULL END,  -- move right
                    CASE WHEN current_setting('game.ducky', true)::int < 16 THEN 4 ELSE NULL END,  -- move down
                    CASE WHEN current_setting('game.duckx', true)::int > 1 AND current_setting('game.ducky', true)::int > 1 THEN 5 ELSE NULL END,  -- move up-left
                    CASE WHEN current_setting('game.duckx', true)::int < 16 AND current_setting('game.ducky', true)::int > 1 THEN 6 ELSE NULL END,  -- move up-right
                    CASE WHEN current_setting('game.duckx', true)::int < 16 AND current_setting('game.ducky', true)::int < 16 THEN 7 ELSE NULL END,  -- move down-right
                    CASE WHEN current_setting('game.duckx', true)::int > 1 AND current_setting('game.ducky', true)::int < 16 THEN 8 ELSE NULL END  -- move down-left
                    ], NULL) AS possible_directions
            )
            SELECT 
                CASE WHEN current_setting('game.direction', true)::int IN (SELECT * FROM unnest(possible_directions.possible_directions)) AND random() < 0.8 THEN
                    current_setting('game.direction', true)::int
                ELSE
                    (SELECT * FROM unnest(possible_directions.possible_directions) ORDER BY RANDOM() LIMIT 1)
                END 
            FROM possible_directions)::text,
            false);
    END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION move_duck(moves INT) RETURNS VOID AS $$
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        IF moves > 0 THEN
            PERFORM set_config('game.duckx', (current_setting('game.duckx', true)::INT + (
            CASE
                WHEN current_setting('game.direction', true)::INT in (1, 5, 8) THEN -1
                WHEN current_setting('game.direction', true)::INT in (2, 4) THEN 0
                ELSE 1
            END
            )::INT)::TEXT, false);
            PERFORM set_config('game.ducky', (current_setting('game.ducky', true)::INT + (
            CASE
                WHEN current_setting('game.direction', true)::INT in (2, 5, 6) THEN -1
                WHEN current_setting('game.direction', true)::INT in (1, 3) THEN 0
                ELSE 1
            END
            )::INT)::TEXT, false);
            RAISE DEBUG 'x,y: %,%', current_setting('game.duckx', true), current_setting('game.ducky', true);
            PERFORM next_direction();
            PERFORM move_duck(moves - 1);
        END IF;
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_move() RETURNS VOID AS $$
DECLARE
    time_difference REAL;
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        SELECT EXTRACT(EPOCH FROM (now() - updated_at)) * 1000 INTO time_difference
            FROM duckhunt
            WHERE id = current_setting('game.id', true)::INT;
        UPDATE duckhunt SET updated_at = now() WHERE id = current_setting('game.id', true)::INT;

        RAISE DEBUG 'ms since last move: %, moves to make: %', time_difference, ceil((time_difference / 10000) * current_setting('game.level', true)::INT)::INT;
        
        PERFORM move_duck(ceil((time_difference / 10000) * current_setting('game.level', true)::INT)::INT);
    END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION shoot(x int, y int)
RETURNS VOID AS $$
DECLARE outcome INT;
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        IF ((current_setting('game.gunx')::INT + x) < 1 OR (current_setting('game.gunx')::INT + x) > 16 OR (current_setting('game.guny')::INT + y) < 1 OR (current_setting('game.guny')::INT + y) > 16) THEN
            RAISE EXCEPTION 'Coordinates out of bounds';
        END IF;

        PERFORM set_config('game.gunx', (current_setting('game.gunx')::INT + x)::text, false);
        PERFORM set_config('game.guny', (current_setting('game.guny')::INT + y)::text, false);
        PERFORM calculate_move();

        PERFORM set_config('game.bullets', (current_setting('game.bullets', true)::INT - 1)::text, false);
        RAISE DEBUG 'bullets: %', current_setting('game.bullets', true);

        SELECT 
            CASE 
                WHEN (current_setting('game.duckx') = current_setting('game.gunx')) AND (current_setting('game.ducky') = current_setting('game.guny')) THEN 1
                WHEN current_setting('game.bullets')::INT <= 0 THEN 2
                ELSE 0
            END AS outcome
        INTO outcome;
        RAISE DEBUG 'outcome: %', outcome;

        UPDATE duckhunt SET ducks = array_cat(ducks, CASE WHEN outcome = 1 THEN ARRAY['🦆'] WHEN outcome = 2 THEN ARRAY['🫥 '] ELSE ARRAY[]::TEXT[] END), shots_fired = shots_fired + 1 WHERE id = current_setting('game.id', true)::INT;
        
        outcome := CASE
            WHEN (SELECT array_length(ducks, 1) FROM duckhunt WHERE id = current_setting('game.id', true)::INT) >= 10 THEN 3
            ELSE outcome
        END;

        IF outcome != 0 THEN
            PERFORM place_duck();
        END IF;
        PERFORM show(outcome, (select ducks from duckhunt where id = current_setting('game.id', true)::INT));
        IF outcome = 3 THEN
            PERFORM stop();
        END IF;
    END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION refresh()
RETURNS VOID AS $$
DECLARE outcome INT;
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        PERFORM calculate_move();
        PERFORM show(-1, (select ducks from duckhunt where id = current_setting('game.id', true)::INT));
    END IF;
END
$$ LANGUAGE plpgsql;
