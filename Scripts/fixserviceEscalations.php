<?php  
  header("Content-Type: text/plain");

  $host = "localhost";
  $username = "root";
  $password = "q2rezeThot";
  $database = "nagios";


  // Connect to database server
  $conn = mysqli_connect($host, $username, $password, $database);

  if (mysqli_connect_errno()) {
    echo "Failed to connect to MySQL: " . mysqli_connect_error();
    exit();
  }

// Get the list of service dependencies so we can swap over the depenedent service with service description
$sql = "SELECT t1.host_name,t1.service_description FROM service t1 LEFT JOIN serviceescalation t2 ON t1.service_description = t2.service_description WHERE t2.service_description IS NULL";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    // Loop through each table

    while ($row = $result->fetch_assoc()) {

        $vi = '';
        $si = '';

        $host_name = $row['host_name'];
        $service_description = $row['service_description'];
        $insertQuery = '';

        if(strpos($service_description, 'OS_Kernel')) {
            echo "String contains OS_Kernel, do nothing";
        } elseif(strpos($service_description, 'ZOMBIES')) {
            echo "String contains ZOMBIES, slow the roll";
            $insertQuery .= "INSERT into serviceescalation (`host_name`,`service_description`,`first_notification`,`last_notification`,`notification_failure_criteria`,`notification_interval`,`contact_groups`) VALUES ('$host_name','$service_description','4','0','120','sysadmin_oncall');";
            $insertQuery .= "INSERT into serviceescalation (`host_name`,`service_description`,`first_notification`,`last_notification`,`notification_failure_criteria`,`notification_interval`,`contact_groups`) VALUES ('$host_name','$service_description','15','0','30', 'noc,sysadmin_email_oncall');";
        } else {
            /*
                MariaDB [nagios]> describe serviceescalation;
                +-----------------------+--------------+------+-----+---------+----------------+
                | Field                 | Type         | Null | Key | Default | Extra          |
                +-----------------------+--------------+------+-----+---------+----------------+
                | id                    | int(255)     | NO   | PRI | NULL    | auto_increment |
                | host_name             | varchar(255) | YES  |     | NULL    |                |
                | hostgroup_name        | varchar(255) | YES  |     | NULL    |                |
                | use                   | varchar(255) | YES  |     | NULL    |                |
                | name                  | varchar(255) | YES  |     | NULL    |                |
                | service_description   | varchar(255) | YES  |     | NULL    |                |
                | contacts              | varchar(255) | YES  |     | NULL    |                |
                | contact_groups        | varchar(255) | YES  |     | NULL    |                |
                | first_notification    | int(10)      | YES  |     | NULL    |                |
                | last_notification     | int(10)      | YES  |     | NULL    |                |
                | notification_interval | varchar(255) | YES  |     | NULL    |                |
                | escalation_period     | varchar(255) | YES  |     | NULL    |                |
                | escalation_options    | varchar(14)  | YES  |     | NULL    |                |
                | notes                 | varchar(255) | YES  |     | NULL    |                |
                | notes_url             | varchar(255) | YES  |     | NULL    |                |
                | action_url            | varchar(255) | YES  |     | NULL    |                |
                | register              | int(1)       | YES  |     | NULL    |                |
                | directory             | varchar(255) | YES  |     | ./      |                |
                | category              | varchar(255) | YES  |     | NULL    |                |
                +-----------------------+--------------+------+-----+---------+----------------+
            */
            
            $insertQuery .= "INSERT into serviceescalation (`host_name`,`service_description`,`first_notification`,`last_notification`,`notification_failure_criteria`,`notification_interval`,`contact_groups`) VALUES ('$host_name','$service_description','4','8','20','noc,sysadmin_oncall');";
            $insertQuery .= "INSERT into serviceescalation (`host_name`,`service_description`,`first_notification`,`last_notification`,`notification_failure_criteria`,`notification_interval`,`contact_groups`) VALUES ('$host_name','$service_description','9','12','20', 'noc,sysadmin_oncall,manager_oncall');";
            $insertQuery .= "INSERT into serviceescalation (`host_name`,`service_description`,`first_notification`,`last_notification`,`notification_failure_criteria`,`notification_interval`,`contact_groups`) VALUES ('$host_name','$service_description','13','14','0', 'noc,sysadmin_oncall,manager_oncall,ohshit_oncall');";
            $insertQuery .= "INSERT into serviceescalation (`host_name`,`service_description`,`first_notification`,`last_notification`,`notification_failure_criteria`,`notification_interval`,`contact_groups`) VALUES ('$host_name','$service_description','15','0','30', 'noc,sysadmin_email_oncall');";
        }
       /* 
        if ($conn->query($updateQuery) === TRUE) {
            echo "INSERTING $host_name - service_description in serviceescalation successfully.\n";
        } else {
            echo "Error INSERTING $column in servicedependency: " . $conn->error . "\n";
        }
        */
        
        print $insertQuery."\n";
    }
}

// Close connection
$conn->close();

echo "fix missing dependencies operation completed.";

?>

