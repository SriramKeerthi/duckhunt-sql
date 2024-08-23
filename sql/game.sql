/* A function which creates a new row in the duckhunt table */

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
           a                   5
 ===#                          6
 # ===      b                  7
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

        INSERT INTO duckhunt (game_level, game, shots_fired, shots_hit, ducks) values (
            game_level, '{"view":[
            [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]]}', 0, 0, ARRAY[]::INTEGER[]
        ) RETURNING id INTO game_id;
        RAISE INFO 'Game ID: %', game_id;
        PERFORM set_config('game.id', game_id::text, false);
        PERFORM show();
    ELSE
        RAISE EXCEPTION 'Game already in progress, stop it with stop() first';
    END IF;
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


CREATE OR REPLACE FUNCTION show() RETURNS VOID AS $$
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        RAISE INFO E'🚀%   🦆0    🔼↑
%', current_setting('game.level', true), current_setting('game.board', true);

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
                SELECT substring(text, 1, ((x-1)*32+(y-1)*2)) || obj || substring(text, ((x-1)*32+y*2 + repl_length)) AS modified_text
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


CREATE OR REPLACE FUNCTION shoot(x int, y int)
RETURNS VOID AS $$
BEGIN
    IF (current_setting('game.id', true) = '0') THEN
        RAISE EXCEPTION 'No game in progress';
    ELSE
        IF (x < 1 OR x > 16 OR y < 1 OR y > 16) THEN
            RAISE EXCEPTION 'Coordinates out of bounds';
        END IF;

        PERFORM set_config('game.board', current_setting('game.template', true), false);
        -- PERFORM place((select floor(random() * 16) + 1)::INT, (select floor(random() * 16) + 1)::INT, '🔴 ', 1);
        PERFORM place(x, y, '🔴 ', 2);

        PERFORM show();
    END IF;
END
$$ LANGUAGE plpgsql;

