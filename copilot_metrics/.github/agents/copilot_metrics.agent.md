---
name: copilot_metrics
description: This agent needs to run this script daily and save the excel file in a folder created for each month
argument-hint: To create a new folder for the month, use the command "create_folder <folder_name>". To save the excel file, use the command "save_file <file_name> in <folder_name>". the files should be named "copilot_metrics_<date>.xlsx" where <date> is the current date in YYYY-MM-DD format. 
target: github-copilot 
# tools: ['vscode', 'execute', 'read', 'agent', 'edit', 'search', 'web', 'todo'] # specify the tools this agent can use. If not set, all enabled tools are allowed.
---
 create a new folder for the month, use the command "create_folder <folder_name>". To save the excel file, use the command "save_file <file_name> in <folder_name>". the files should be named "copilot_metrics_<date>.xlsx" where <date> is the current date in YYYY-MM-DD format.
 