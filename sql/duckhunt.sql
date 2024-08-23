/**
 * This is a bad idea
 */

CREATE DATABASE duckhunt;
USE duckhunt;

CREATE TABLE duckhunt (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    game_level   INT NOT NULL,
    game         JSONB NOT NULL,
    shots_fired  INT NOT NULL,
    shots_hit    INT NOT NULL,
    ducks        INT[] NOT NULL,
    
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
   IF row(NEW.*) IS DISTINCT FROM row(OLD.*) THEN
      NEW.updated_at = now(); 
      RETURN NEW;
   ELSE
      RETURN OLD;
   END IF;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_game_modified BEFORE UPDATE ON duckhunt FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
