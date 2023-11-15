
-- CREATE DATABASE AND SCHEMA
CREATE DATABASE ncaaf;
CREATE SCHEMA ncaaf_games;

-- Create a table for college football teams
CREATE TABLE college_football_schema.teams (
    team_id SERIAL PRIMARY KEY AUTO_INCREMENT,
    team_name VARCHAR(255) NOT NULL);

-- ALTER DATATYPE TO MATCH FOREIGN KEY COLUMNS
ALTER TABLE ncaaf_games.teams MODIFY team_id INT;

-- CREATE TABLE FOR GAME STATS
CREATE TABLE ncaaf_games.games(
    game_id SERIAL PRIMARY KEY,
    home_team_id INT,
    away_team_id INT,
    game_date DATE,
    home_team_score INT,
    away_team_score INT,
    FOREIGN KEY (home_team_id) REFERENCES ncaaf_games.teams(team_id),
    FOREIGN KEY (away_team_id) REFERENCES ncaaf_games.teams(team_id));

-- INSERT DATA FOR TOP 10 COLLEGE FOOTBALL TEAMS AND THE TEAMS THEY PLAYED MOST RECENTLY
INSERT INTO ncaaf_games.teams (team_name) VALUES
('Georgia'),
('Michigan'),
('Ohio State'),
('Florida State'),
('Washington'),
('Oklahoma'),
('Penn State'),
('Texas'),
('Oregon'),
('North Carolina'),
('Vanderbilt'),
('Michigan State'),
('Duke'),
('Arizona State'),
('UCF'),
('Houston'),
('Washington State'),
('Virginia');

-- VALIDATE RANKINGS
SELECT * FROM ncaaf_games.teams;

-- ADDING ADDITIONAL PERFORMANCE METRICS TO GAME STATS TABLE
ALTER TABLE ncaaf_games.games 
ADD home_team_rank INT,
ADD away_team_rank INT,
ADD home_team_points_allowed INT,
ADD away_team_points_allowed INT,
ADD home_team_total_yards_gained INT,
ADD away_team_total_yards_gained INT,
ADD home_team_turnovers INT,
ADD away_team_turnovers INT,
ADD home_team_total_yards_allowed INT,
ADD away_team_total_yards_allowed INT; 

-- Insert data for the last game performance of each team
INSERT INTO ncaaf_games.games (home_team_id, away_team_id, game_date, home_team_score, away_team_score,
home_team_rank, away_team_rank,
home_team_points_allowed, away_team_points_allowed,
home_team_total_yards_gained, away_team_total_yards_gained,
home_team_turnovers, away_team_turnovers,
home_team_total_yards_allowed, away_team_total_yards_allowed) 
VALUES
    (11, 1, '2023-10-21', 20, 37,95,1,37,20,219,552,-1,-2,552,219),
    (12, 2, '2023-10-21', 0, 49,86,2,49,0,182,477,-2,0,477,182),
    (3, 7, '2023-10-21', 20, 12,3,7,12,20,365,240,-1,0,240,365),
    (4, 13, '2023-10-21', 38, 20,4,20,20,38,420,273,-1,-1,273,420),
    (5, 14, '2023-10-21', 15, 7,5,99,7,15,288,341,-4,-1,341,288),
    (6, 15, '2023-10-21', 31,29,6,61,29,31,442,397,-1,0,397,442),
    (16, 8, '2023-10-21', 24,31,70,8,31,24,392,360,-2,0,360,392),
    (9, 17, '2023-10-21', 38, 24,9,29,24,38,541,495,0,0,495,541),
    (10, 18, '2023-10-21', 27,31,10,117,31,27,490,436,-1,-2,436,490);

-- VALIDATE ALL GAME STAT DATA IS PRESENT
SELECT * FROM ncaaf_games.games;

/*
Each stat has a weight (% out of 100) I can just do  10, 15, 20, 25, 30
* 30% = Win
* 25% = Win vs higher ranked opponent
* 20% = points scored - points allowed  = point differential
* 15% = yards gained - yards allowed = yard differential
* 10% = turnover differential

Each category has a point system
* Win = 100 points
* Win vs higher ranked opponent = 100
* Point differential = 2 per point
* Yard differential = .25 per yard
* Turnover differential = 30
*/

/* CREATE CTE FOR TOTAL POINTS AWARDED TO EACH TEAM BASED ON PERFORMANCE OF MOST RECENT GAME*/
WITH cte_points AS (
SELECT
    t.team_id,
    t.team_name AS team_name,
    g.game_date AS last_game_date,
    CASE -- points for a win
        WHEN g.home_team_id = t.team_id 
        AND g.home_team_score > g.away_team_score 
        THEN 100*.3 
        ELSE 
            CASE 
		WHEN g.away_team_id = t.team_id 
            	AND g.away_team_score > g.home_team_score 
            	THEN 100*.30 
            	ELSE 0 END 
    END AS win_pts,		
    CASE -- points for a win vs an opponent
	WHEN g.home_team_id = t.team_id 
	AND g.home_team_score > g.away_team_score 
	AND g.away_team_id <=10 
	THEN 100*.25 
        ELSE 		
	    CASE 	
		WHEN g.away_team_id = t.team_id 
                AND g.away_team_score > g.home_team_score 
        	AND g.home_team_id <=10                 	
		THEN 100*.25 
                ELSE 0 END 
    END AS WinVsRankopp_pts,	
    CASE -- points for how many more points a team scored than the opponent 
	WHEN g.home_team_id = t.team_id 
        THEN (g.home_team_score - g.away_team_score) * 2 * .20  
        ELSE (g.away_team_score - g.home_team_score) * 2 * .20 
	END AS score_diff_pts,
    CASE -- points for how many more yards a team gained than their opponent
	WHEN g.home_team_id = t.team_id 
        THEN (g.home_team_total_yards_gained - g.away_team_total_yards_gained) * .25 * .15 
        ELSE (g.away_team_total_yards_gained - g.home_team_total_yards_gained) * .25 * .15 
	END AS yds_diff_pts,
    CASE -- points for turnover differential		
	WHEN g.home_team_id = t.team_id 
        THEN (g.home_team_turnovers - g.away_team_turnovers) * 30 * .10 
        ELSE (g.away_team_turnovers - g.home_team_turnovers) * 2 * .10 
	END AS to_diff_pts
FROM ncaaf_games.teams AS t
JOIN ncaaf_games.games AS g 
ON (t.team_id = g.home_team_id OR t.team_id = g.away_team_id)
ORDER BY t.team_id)

-- Use the CTE to add up all points for each category and return total ranking points then re-rank each top 10 team
SELECT 
    ROW_NUMBER() OVER (ORDER BY win_pts + WinVsRankopp_pts + score_diff_pts + yds_diff_pts + to_diff_pts DESC) 
    AS new_ranking,
    team_name, win_pts + WinVsRankopp_pts + score_diff_pts + yds_diff_pts + to_diff_pts 
    AS total_pts
FROM 
    cte_points
WHERE 
    team_id BETWEEN 1 AND 10
ORDER BY total_pts DESC;





















