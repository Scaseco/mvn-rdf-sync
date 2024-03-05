#!/bin/python

# This script generates a maven project setup for benchmarking
# maven repository performance when down stream processes are attached to it.

# Technically, this script generates a parent pom with N sub-modules
# For each sub module an RDF data set is generated.

# Running mvn install / deploy on the parent then runs the build on the sub-modules.

import os

from urllib.parse import urlparse
from pathlib import Path
from string import Template
from jinja2 import Environment, FileSystemLoader
import xml.etree.ElementTree as ET

group_id = 'org.aksw.maven4data.repobench-rdf'
artifactId = 'repobench-rdf'
version = '0.0.1-SNAPSHOT'
project_prefix = "repobench-"

parent_str = """
<parent>
  <groupId>org.aksw.data.config</groupId>
  <artifactId>aksw-data-deployment</artifactId>
  <version>0.0.8</version><relativePath>
  </relativePath>
</parent>
"""

def prettify_xml(s):
  return s
  #xml = ET.fromstring(s)
  #ET.indent(xml)
  #result = ET.tostring(xml, encoding='unicode')
  #return result


build_path = 'target/build'
consumer_path = 'target/consumer'
os.makedirs(build_path, exist_ok=True)
os.makedirs(consumer_path, exist_ok=True)

env = Environment(loader=FileSystemLoader('resources'))
artifact_template = env.get_template('artifact.template.pom.xml')
parent_template = env.get_template('parent.template.pom.xml')
consumer_template = env.get_template('consumer.template.pom.xml')

# Open the file and process each line
modules = []
for sub_module_idx in range(1, 500):
  triple_count = sub_module_idx * 1000
  # artifact_id = f'{project_prefix}{triple_count}'
  artifact_id = f'{project_prefix}{sub_module_idx}'

  module_name = artifact_id
  module_folder=f'{build_path}/{module_name}'
  data_path = f'{module_folder}/data.nt'
  module_folder=f'{build_path}/{module_name}'

  print(f"Generating module {artifact_id} ...")

  os.makedirs(module_folder, exist_ok=True)
  with open(data_path, "w") as file:
    for i in range(0, triple_count):
      file.write(f'<https://www.example.org/subject{i}> <https://www.example.org/predicate{i}> <https://www.example.org/object{i}> .\n')

  data_module_path = os.path.relpath(data_path, module_folder)

  module = {
    "moduleName": module_name,
    "parentStr": parent_str,
    "groupId": group_id,
    "artifactId": artifact_id,
    "version": version,
    "description": f'RepoBench Module with {triple_count} Triples.',
    "licenses": [{
      "name": "Creative Commons Attribution 4.0",
      "url": "https://creativecommons.org/licenses/by/4.0/"
    }],
    "data": {
      "path": data_module_path,
      "type": "nt"
    }
  }
  rendered = artifact_template.render(this=module)
  rendered = prettify_xml(rendered)
  modules.append(module)
  os.makedirs(module_folder, exist_ok=True)
  with open(f'{module_folder}/pom.xml', "w") as file:
    file.write(rendered)

  parent = {
    "parentStr": parent_str,
    "groupId": group_id,
    "artifactId": f'{project_prefix}parent',
    "version": version,
    "modules": modules
  }
  rendered = parent_template.render(this=parent)
  rendered = prettify_xml(rendered)
  with open(f'{build_path}/pom.xml', "w") as file:
    file.write(rendered)

  consumer = {
    "parentStr": parent_str,
    "groupId": group_id,
    "artifactId": f'{project_prefix}consumer',
    "version": version,
    "modules": modules
  }
  rendered = consumer_template.render(this=consumer)
  rendered = prettify_xml(rendered)
  with open(f'{consumer_path}/pom.xml', "w") as file:
    file.write(rendered)


