CREATE DATABASE IF not exists school_database;


CREATE TABLE users (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('Inspector', 'Technician', 'Admin')),
  email VARCHAR(100) UNIQUE,
  phone_number CHAR(15),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the schools table
CREATE TABLE schools (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  name VARCHAR(100) NOT NULL UNIQUE,
  address VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100) NOT NULL,
  zip VARCHAR(20) NOT NULL,
  phone_number CHAR(15) NOT NULL,
  email VARCHAR(100) UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the buildings table
CREATE TABLE buildings (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  school_id CHAR(36) REFERENCES schools(id),
  name VARCHAR(100) NOT NULL,
  type VARCHAR(50) NOT NULL CHECK (type IN ('Administration', 'Classroom', 'Gymnasium', 'Laboratory', 'Library', 'Other')),
  square_footage INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the infrastructure_components table
CREATE TABLE infrastructure_components (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the buildings_infrastructure table (many-to-many relationship)
CREATE TABLE buildings_infrastructure (
  building_id CHAR(36) REFERENCES buildings(id),
  component_id CHAR(36) REFERENCES infrastructure_components(id),
  PRIMARY KEY (building_id, component_id)
);

-- Create the sensors table
CREATE TABLE sensors (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  name VARCHAR(100) NOT NULL UNIQUE,
  type VARCHAR(50) NOT NULL CHECK (type IN ('Temperature', 'Humidity', 'AirQuality', 'Structural', 'Vision')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the buildings_sensors table (many-to-many relationship)
CREATE TABLE buildings_sensors (
  building_id CHAR(36) REFERENCES buildings(id),
  sensor_id CHAR(36) REFERENCES sensors(id),
  PRIMARY KEY (building_id, sensor_id)
);

-- Create the inspection_reports table
CREATE TABLE inspection_reports (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  building_id CHAR(36) REFERENCES buildings(id),
  inspector_id CHAR(36) REFERENCES users(id),
  report_date DATE NOT NULL,
  condition INT NOT NULL CHECK (condition BETWEEN 1 AND 5),
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the maintenance_requests table
CREATE TABLE maintenance_requests (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  building_id CHAR(36) REFERENCES buildings(id),
  component_id CHAR(36) REFERENCES infrastructure_components(id),
  request_date DATE NOT NULL,
  description TEXT NOT NULL,
  priority INT NOT NULL CHECK (priority BETWEEN 1 AND 3),
  status VARCHAR(50) NOT NULL CHECK (status IN ('Open', 'In Progress', 'Completed', 'Cancelled')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create the maintenance_history table
CREATE TABLE maintenance_history (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  maintenance_request_id CHAR(36) REFERENCES maintenance_requests(id),
  technician_id CHAR(36) REFERENCES users(id),
  work_date DATE NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create indexes for efficient querying
CREATE INDEX idx_schools_name ON schools(name);
CREATE INDEX idx_buildings_school_id ON buildings(school_id);
CREATE INDEX idx_infrastructure_components_name ON infrastructure_components(name);
CREATE INDEX idx_sensors_name ON sensors(name);
CREATE INDEX idx_inspection_reports_building_id ON inspection_reports(building_id);
CREATE INDEX idx_maintenance_requests_building_id ON maintenance_requests(building_id);
CREATE INDEX idx_maintenance_history_maintenance_request_id ON maintenance_history(maintenance_request_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- Note: MySQL does not support row-level security policies in the same way as PostgreSQL.

SELECT b.name AS building_name, ic.name AS component_name, ir.condition, ir.notes
FROM inspection_reports ir
JOIN buildings b ON ir.building_id = b.id
JOIN infrastructure_components ic ON ic.id = (SELECT component_id FROM maintenance_requests WHERE id = ir.id);

SELECT ir.report_date, AVG(ir.condition) AS avg_condition
FROM inspection_reports ir
GROUP BY ir.report_date
ORDER BY ir.report_date;

SELECT mr.id, b.name AS building_name, ic.name AS component_name, mr.priority, mr.status
FROM maintenance_requests mr
JOIN buildings b ON mr.building_id = b.id
JOIN infrastructure_components ic ON mr.component_id = ic.id
WHERE mr.status = 'Open'
ORDER BY mr.priority ASC;

SELECT u.username, COUNT(mr.id) AS requests_handled, COUNT(mh.id) AS repairs_done
FROM maintenance_requests mr
JOIN maintenance_history mh ON mr.id = mh.maintenance_request_id
JOIN users u ON mh.technician_id = u.id
GROUP BY u.username;

CREATE VIEW view_current_conditions AS
SELECT b.name AS building_name, ic.name AS component_name, ir.condition, ir.notes
FROM inspection_reports ir
JOIN buildings b ON ir.building_id = b.id
JOIN infrastructure_components ic ON ic.id = (SELECT component_id FROM maintenance_requests WHERE id = ir.id);

DELIMITER //
CREATE PROCEDURE get_urgent_repairs()
BEGIN
    SELECT mr.id, b.name AS building_name, ic.name AS component_name, mr.priority, mr.status
    FROM maintenance_requests mr
    JOIN buildings b ON mr.building_id = b.id
    JOIN infrastructure_components ic ON mr.component_id = ic.id
    WHERE mr.status = 'Open'
    ORDER BY mr.priority ASC;
END //
DELIMITER ;
