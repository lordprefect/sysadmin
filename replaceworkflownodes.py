#!/usr/bin/python
import json
import re
from contextlib import redirect_stdout

with open("workflow_working.json","r") as file:
    data = json.load(file)

def get_dict_values(data):
    # Initialize an empty list to store the values
    values = []

    # default value setzen
    workflownode = {"extra_data": ""}
    workflownode = {"identifier": ""}
    workflownode = {"description": ""}
    # Check if the input dictionary has the key "job_templates"
    if "workflow_job_templates" in data:
        # Iterate over each job template
        for workflow_job_template in data["workflow_job_templates"]:
            line=(json.dumps(workflow_job_template, indent=4))
            workflow_job_template["inventory"] = {"name": "inv_manageiq"}

            if "always_nodes" in line:
                for workflownode in workflow_job_template["related"]["workflow_nodes"]:
                    line = re.sub(r'(.*identifier.*)',r'\1\n                "workflow_job_template": {\n
              "organization": {\n                    "name": "GoSYS",\n                    "type": "organiza
tion"\n                  },\n                  "name": "WORKFLOWJOBNAME",\n                  "type": "workfl
ow_job_template"\n                },\n                "unified_job_template": {\n                  "organiza
tion": {\n                    "name": "GoSYS",\n                    "type": "organization"\n
  },\n                  "name": "UNIFIEDJOBTEMPLATE",\n                  "type": "job_template"\n
     },\n                "related": {\n                  "credentials": []\n                  "success_nodes
": SUCCESSNODES,\n                  "failure_nodes": FAILURENODES,\n                  "always_nodes": ALWAYS
NODES,\n                  },\n                "natural_key": {\n                  "workflow_job_template": {
\n                    "organization": {\n                      "name": "GoSYS",\n                      "type
": "organization"\n                      },\n                  "name": "WORKFLOWJOBNAME",\n
 "type": "workflow_job_template"\n                  },\n  \1\n                  "type": "workflow_job_templa
te_node"\n                },',line)
#                    print('       },')
                    if "Deaktivieren des Host Monitoring der VMware Cluster in Prod" in line:
                        workflow_job_template["inventory"] = {"name": "localhost"}
                    if "vc-prod - VMware Ressource Shares Set" in line:
                        workflow_job_template["inventory"] = {"name": "localhost"}
                    if "Colocation-Tag" in line:
                        workflow_job_template["inventory"] = {"name": "localhost"}
                    line = re.sub(r'JOBTEMPLATENAME',rf'{workflownode["name"]}', line)
                    line = re.sub(r'WORKFLOWJOBNAME',rf'{workflow_job_template["name"]}', line)
                    line = re.sub(r'UNIFIEDJOBTEMPLATE',rf'{workflownode["unified_job_name"]}', line)
                    if workflownode["success_nodes"]:
                      line = re.sub(r'SUCCESSNODES',r'[\n                  "workflow_job_template": {\n
               "organization": {\n                      "name": "GoSYS",\n                      "type": "org
anization"\n                      },\n                  "name": "FOOBAR",\n                  "type": "workfl
ow_job_template"\n                  },\n                  "identifier": "{workflownode["identifier"]}\n
             "type": "workflow_job_template_node"\n                }', line)
                      line = re.sub(r'FOOBAR',rf'{workflownode["success_nodes"]}', line)
                    else:
                      line = re.sub(r'SUCCESSNODES',rf'{workflownode["success_nodes"]}', line)
                    line = re.sub(r'FAILURENODES',rf'{workflownode["failure_nodes"]}', line)
                    line = re.sub(r'ALWAYSNODES',rf'{workflownode["always_nodes"]}', line)
                    print(f'{line}')
            else:
                print(line)


get_dict_values(data)
