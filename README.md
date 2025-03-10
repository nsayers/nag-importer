# nag-importer
Nagios importer and exporter to and from SQL for bulk updating

Grabs the files from a specific directory and loads them into a sql table so we can adjust them as needed.  

Since I am not happy with the multiple paths for the config files to be written and the inconsistencies between a group of individuals, I must outline that I keep all the different definitions for a single host in a single file, and only add commands, group *(definitions only, no members)* and template work outside of the conf.d/ folder.  each host is considered independent and therefore is a single file.  It is simple to copy and paste a new site/deployment and run a sed command to reconfigure each file for simplistic deployment.  I am pretty sure you can see how this works and how it can be scaled once you get a few thousand checks running.  
