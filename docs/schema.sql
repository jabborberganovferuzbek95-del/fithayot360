-- FitHayot 360 v3: PostgreSQL sxemasi (modellardan generatsiya)

CREATE TABLE activity_types (
	id SERIAL NOT NULL, 
	code VARCHAR(30) NOT NULL, 
	title VARCHAR(80) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (code)
);


CREATE TABLE exercise_categories (
	id SERIAL NOT NULL, 
	code VARCHAR(40) NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	mode VARCHAR(10) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_category_mode CHECK (mode IN ('home','gym')), 
	UNIQUE (code)
);


CREATE TABLE meditation_items (
	id SERIAL NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	category VARCHAR(15) NOT NULL, 
	duration_min INTEGER NOT NULL, 
	description TEXT NOT NULL, 
	guide TEXT NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_med_category CHECK (category IN ('stress','focus','sleep','motivation'))
);


CREATE TABLE programs (
	id SERIAL NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	description TEXT NOT NULL, 
	mode VARCHAR(10) NOT NULL, 
	kind VARCHAR(15) NOT NULL, 
	difficulty VARCHAR(20) NOT NULL, 
	duration_min INTEGER NOT NULL, 
	image_url VARCHAR(500), 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_program_mode CHECK (mode IN ('home','gym')), 
	CONSTRAINT ck_program_kind CHECK (kind IN ('full_body','strength','stretch','cardio'))
);

CREATE INDEX ix_programs_title ON programs (title);

CREATE TABLE recipes (
	id SERIAL NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	meal_type VARCHAR(15) NOT NULL, 
	kcal INTEGER NOT NULL, 
	prep_minutes INTEGER NOT NULL, 
	ingredients TEXT NOT NULL, 
	instructions TEXT NOT NULL, 
	image_url VARCHAR(500), 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_recipe_type CHECK (meal_type IN ('breakfast','lunch','dinner','snack','detox'))
);

CREATE INDEX ix_recipes_title ON recipes (title);

CREATE TABLE users (
	id SERIAL NOT NULL, 
	email VARCHAR(255) NOT NULL, 
	password_hash VARCHAR(255) NOT NULL, 
	role VARCHAR(20) NOT NULL, 
	is_adult_confirmed BOOLEAN NOT NULL, 
	full_name VARCHAR(100), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_users_role CHECK (role IN ('user','content_admin','system_admin'))
);

CREATE UNIQUE INDEX ix_users_email ON users (email);

CREATE TABLE activity_logs (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	activity_type_id INTEGER NOT NULL, 
	occurred_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	duration_minutes INTEGER NOT NULL, 
	distance_km FLOAT, 
	note VARCHAR(500), 
	idempotency_key VARCHAR(64), 
	PRIMARY KEY (id), 
	CONSTRAINT ck_activity_duration CHECK (duration_minutes > 0), 
	CONSTRAINT ck_activity_distance CHECK (distance_km IS NULL OR distance_km >= 0), 
	CONSTRAINT uq_activity_idem UNIQUE (user_id, idempotency_key), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(activity_type_id) REFERENCES activity_types (id)
);

CREATE INDEX ix_activity_user_time ON activity_logs (user_id, occurred_at);

CREATE TABLE consent_events (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	policy_version VARCHAR(20) NOT NULL, 
	purpose VARCHAR(60) NOT NULL, 
	accepted_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	revoked_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_consent_events_user_id ON consent_events (user_id);

CREATE TABLE exercises (
	id SERIAL NOT NULL, 
	category_id INTEGER NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	description TEXT NOT NULL, 
	equipment VARCHAR(100) NOT NULL, 
	difficulty VARCHAR(20) NOT NULL, 
	duration_hint VARCHAR(50), 
	safety_note TEXT NOT NULL, 
	image_url VARCHAR(500), 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_exercise_difficulty CHECK (difficulty IN ('beginner','intermediate','advanced')), 
	FOREIGN KEY(category_id) REFERENCES exercise_categories (id)
);

CREATE INDEX ix_exercises_category_active ON exercises (category_id, is_active);
CREATE INDEX ix_exercises_title ON exercises (title);

CREATE TABLE fitness_profiles (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	goal VARCHAR(30), 
	experience_level VARCHAR(20), 
	preferred_location VARCHAR(20), 
	daily_minutes INTEGER, 
	activity_level VARCHAR(20), 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_profile_minutes CHECK (daily_minutes IS NULL OR (daily_minutes BETWEEN 5 AND 300)), 
	UNIQUE (user_id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);


CREATE TABLE habits (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	title VARCHAR(100) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_habits_user_id ON habits (user_id);

CREATE TABLE meal_logs (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	recipe_id INTEGER, 
	title VARCHAR(150) NOT NULL, 
	meal_type VARCHAR(15) NOT NULL, 
	kcal INTEGER NOT NULL, 
	eaten_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_meal_kcal CHECK (kcal >= 0), 
	CONSTRAINT ck_meal_type CHECK (meal_type IN ('breakfast','lunch','dinner','snack')), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(recipe_id) REFERENCES recipes (id) ON DELETE SET NULL
);

CREATE INDEX ix_meal_user_time ON meal_logs (user_id, eaten_at);

CREATE TABLE meditation_logs (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	item_id INTEGER, 
	duration_min INTEGER NOT NULL, 
	completed_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_medlog_duration CHECK (duration_min > 0), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(item_id) REFERENCES meditation_items (id) ON DELETE SET NULL
);

CREATE INDEX ix_meditation_logs_user_id ON meditation_logs (user_id);

CREATE TABLE premium_interest (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (user_id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);


CREATE TABLE sleep_logs (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	sleep_date DATE NOT NULL, 
	duration_min INTEGER NOT NULL, 
	quality INTEGER, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_sleep_duration CHECK (duration_min > 0), 
	CONSTRAINT ck_sleep_quality CHECK (quality IS NULL OR (quality BETWEEN 1 AND 5)), 
	CONSTRAINT uq_sleep_day UNIQUE (user_id, sleep_date), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);


CREATE TABLE step_logs (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	day DATE NOT NULL, 
	steps INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_steps_nonneg CHECK (steps >= 0), 
	CONSTRAINT uq_steps_day UNIQUE (user_id, day), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);


CREATE TABLE user_goals (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	steps_goal INTEGER NOT NULL, 
	water_goal_ml INTEGER NOT NULL, 
	sleep_goal_min INTEGER NOT NULL, 
	workout_goal_min INTEGER NOT NULL, 
	calorie_goal INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (user_id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);


CREATE TABLE user_settings (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	language_code VARCHAR(5) NOT NULL, 
	reminders_enabled BOOLEAN NOT NULL, 
	privacy_version VARCHAR(20), 
	PRIMARY KEY (id), 
	UNIQUE (user_id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);


CREATE TABLE water_logs (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	amount_ml INTEGER NOT NULL, 
	logged_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	idempotency_key VARCHAR(64), 
	PRIMARY KEY (id), 
	CONSTRAINT ck_water_amount CHECK (amount_ml > 0), 
	CONSTRAINT uq_water_idem UNIQUE (user_id, idempotency_key), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_water_user_time ON water_logs (user_id, logged_at);

CREATE TABLE workout_plans (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	title VARCHAR(150) NOT NULL, 
	starts_on DATE NOT NULL, 
	ends_on DATE NOT NULL, 
	status VARCHAR(15) NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_plan_dates CHECK (ends_on >= starts_on), 
	CONSTRAINT ck_plan_status CHECK (status IN ('active','archived')), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_plans_user ON workout_plans (user_id);

CREATE TABLE content_audit (
	id SERIAL NOT NULL, 
	admin_user_id INTEGER, 
	exercise_id INTEGER NOT NULL, 
	action VARCHAR(20) NOT NULL, 
	occurred_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(admin_user_id) REFERENCES users (id) ON DELETE SET NULL, 
	FOREIGN KEY(exercise_id) REFERENCES exercises (id)
);


CREATE TABLE habit_checks (
	id SERIAL NOT NULL, 
	habit_id INTEGER NOT NULL, 
	day DATE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_habit_day UNIQUE (habit_id, day), 
	FOREIGN KEY(habit_id) REFERENCES habits (id) ON DELETE CASCADE
);

CREATE INDEX ix_habit_checks_habit_id ON habit_checks (habit_id);

CREATE TABLE plan_items (
	id SERIAL NOT NULL, 
	plan_id INTEGER NOT NULL, 
	exercise_id INTEGER NOT NULL, 
	planned_date DATE NOT NULL, 
	planned_minutes INTEGER NOT NULL, 
	sort_order INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_item_minutes CHECK (planned_minutes > 0), 
	FOREIGN KEY(plan_id) REFERENCES workout_plans (id) ON DELETE CASCADE, 
	FOREIGN KEY(exercise_id) REFERENCES exercises (id)
);

CREATE INDEX ix_plan_items_plan_date ON plan_items (plan_id, planned_date);

CREATE TABLE program_items (
	id SERIAL NOT NULL, 
	program_id INTEGER NOT NULL, 
	exercise_id INTEGER NOT NULL, 
	seconds INTEGER, 
	reps INTEGER, 
	sort_order INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_pitem_target CHECK (seconds IS NOT NULL OR reps IS NOT NULL), 
	FOREIGN KEY(program_id) REFERENCES programs (id) ON DELETE CASCADE, 
	FOREIGN KEY(exercise_id) REFERENCES exercises (id)
);

CREATE INDEX ix_program_items_program_id ON program_items (program_id);

CREATE TABLE workout_sessions (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	plan_id INTEGER, 
	started_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	finished_at TIMESTAMP WITH TIME ZONE, 
	status VARCHAR(15) NOT NULL, 
	mode VARCHAR(10) NOT NULL, 
	notes TEXT, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_session_times CHECK (finished_at IS NULL OR finished_at >= started_at), 
	CONSTRAINT ck_session_status CHECK (status IN ('in_progress','completed','interrupted')), 
	CONSTRAINT ck_session_mode CHECK (mode IN ('home','gym')), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(plan_id) REFERENCES workout_plans (id) ON DELETE SET NULL
);

CREATE INDEX ix_sessions_user_started ON workout_sessions (user_id, started_at);

CREATE TABLE exercise_logs (
	id SERIAL NOT NULL, 
	session_id INTEGER NOT NULL, 
	exercise_id INTEGER NOT NULL, 
	plan_item_id INTEGER, 
	set_no INTEGER NOT NULL, 
	reps INTEGER, 
	weight_kg FLOAT, 
	duration_seconds INTEGER, 
	completed_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	idempotency_key VARCHAR(64), 
	PRIMARY KEY (id), 
	CONSTRAINT ck_log_set CHECK (set_no > 0), 
	CONSTRAINT ck_log_reps CHECK (reps IS NULL OR reps > 0), 
	CONSTRAINT ck_log_weight CHECK (weight_kg IS NULL OR weight_kg >= 0), 
	CONSTRAINT ck_log_duration CHECK (duration_seconds IS NULL OR duration_seconds > 0), 
	CONSTRAINT ck_log_has_value CHECK (reps IS NOT NULL OR duration_seconds IS NOT NULL), 
	CONSTRAINT uq_log_idem UNIQUE (session_id, idempotency_key), 
	FOREIGN KEY(session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE, 
	FOREIGN KEY(exercise_id) REFERENCES exercises (id), 
	FOREIGN KEY(plan_item_id) REFERENCES plan_items (id) ON DELETE SET NULL
);

CREATE INDEX ix_exercise_logs_plan_item_id ON exercise_logs (plan_item_id);
CREATE INDEX ix_exercise_logs_session_id ON exercise_logs (session_id);
