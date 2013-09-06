# Script that transforms pomaid files into pom.xml.
# pomaid syntax:
#
# Define the project groupId
# groupId: your-group
#
# Define the project artifactId
# artifactId: your-artifact
#
# Define the project version
# version: your.version
#
# Add any element that only has embedded text and not embedded elements. (e.g. <source>1.7</source>)
# source: 1.7
#
# Add a single dependency (version is optional)
# + groupId:artifactId:version
#
# Add a variety of dependencies for a group (version is optional)
# + groupId
#   :artifactId:version
#   :artifactId2:version
#
# Exclude a dependency from the most recent dependency in the file
# - groupId:artifactId:version
#
# Create a property
# a.b.c = 1.4.5
#
# Copy literal text into pom
# ```
# <build>
#   <plugins>
#   </plugins>
# </build>
# ```

# Given a string separated by delimiter, return the last items after the first n items as a new string
# "a b c", 1 will return "b c"
function chop_n_of_string(string, delimiter, n,    return_string,    string_pieces,   last_index,   cur_string) {
  split(string, string_pieces, delimiter)
  last_index = length(string_pieces)
  for (array_index = n + 1; array_index <= last_index; array_index++) {
    if (array_index != n + 1) {
      # don't print the first delimiter
      
      return_string = (return_string delimiter string_pieces[array_index])
    } else {
      return_string = string_pieces[array_index]
      
      # clean out leading whitespace (caused if the delimiter isn't a space)
      sub(/[ \t\r\n]*/, "", return_string)
    }
  }
  return return_string
}


# Creates a string of amount spaces
function indent_spaces(amount,  returnString) {
  for (i = 1; i <= amount; i++) {
     returnString = returnString " "
  }
  return returnString
}

# Given an level, return level * 2 spaces. For example, an indent level of 1 would return two spaces
function indent_level(level) {
  return indent_spaces(level * 2)
}

# Create the <dependencies> element, but only if necessary
function start_dependencies() {
  close_hierarchy(yaml_hierarchy, 1)
  close_properties()
  if (!has_printed_dependencies) {
     has_printed_dependencies = 1
     indent_print(as_start_element("dependencies"))
     increment_indent()
  }
}

# Opens the properties element, if needed
function start_properties() {
  close_hierarchy(yaml_hierarchy, 1)
  if (!has_printed_properties) {
    indent_print(as_start_element("properties"))
    increment_indent()
    has_printed_properties = 1
  }
}

# Opens the exclusions tag
function start_exclusions() {
  if (!has_printed_exclusions) {
     indent_print(as_start_element("exclusions"))
     increment_indent()
     has_printed_exclusions = 1
  }
}

# Closes the exclusions tag
function close_exclusions() {
  if (has_printed_exclusions) {
    decrement_indent()
    indent_print(as_end_element("exclusions"))
    has_printed_exclusions = 0
  }
}

# Start a single dependency
function start_dependency() {
  start_dependencies(); close_dependency();
  
  if (has_printed_dependency == 0) {
     indent_print(as_start_element("dependency"))
     increment_indent()
     has_printed_dependency = 1
  }
}

# Close the dependency tag if there's a current dependency
function close_dependency() {
  if (has_printed_dependency == 1) {
    close_exclusions()
    decrement_indent()
    indent_print(as_end_element("dependency"))
    has_printed_dependency = 0
  }
}

# Close out the dependencies tag if necessary
function close_dependencies() {
  if (has_printed_dependencies) {
    close_dependency()
    decrement_indent()
    indent_print(as_end_element("dependencies"))
    has_printed_dependencies = 0
  }
}

function close_properties() {
  if(has_printed_properties) {
    decrement_indent()
    indent_print(as_end_element("properties"))
    print ""
  }
  has_printed_properties = 0
}

# Decrements the current indent
function decrement_indent() {
  if (current_indent_level > 0) {
    current_indent_level --
  }
}

# Increments the current indent
function increment_indent() {
  current_indent_level++
}

# wraps text in element
function as_text_only_element(element_name, text) {
  return as_start_element(element_name) text as_end_element(element_name)
}

# wraps the text in an xml starting element
function as_start_element(text) {
  return "<" text ">"
}

# wraps the text in an xml ending element
function as_end_element(text) {
  return "</" text ">"
}

# Like print, but indents for the appropriate amount
function indent_print(text) {
  print indent_level(current_indent_level) text  
}

# Close out the last n hierarchy of elements for yaml style nesting
# hierarchy: the current list of items in the yaml-style hierarch
# up_through: the index (plus followers) of the item to close out (and delete from the array)
function close_hierarchy(hierarchy, up_through) {
  for (hierarchy_index = length(hierarchy); hierarchy_index >= up_through; hierarchy_index--) {
     decrement_indent()
     indent_print(as_end_element(hierarchy[hierarchy_index]))
     delete hierarchy[hierarchy_index]
  }
}

# Given an array of strings, delete any that are longer than the passed-in string
# array: array of items to investigate
# max_length_string: the longest string that should be allowed in the list
function delete_entries_longer_than(array, max_length_string,   items_to_delete_index,   items_to_delete) {
  for (item in array) {
    if (length(item) > length(max_length_string)) {
      items_to_delete[length(items_to_delete) + 1] = item
    }
  }
  
  for (item_to_delete in items_to_delete) {
    delete array[item_to_delete]
  }
}


# print a dependency item
function print_dependency(groupId, artifactId, version) {
  indent_print(as_text_only_element("groupId", groupId))
  indent_print(as_text_only_element("artifactId", artifactId))
  if (version) {
    indent_print(as_text_only_element("version", version))
  }
}


BEGIN {
  # state variables
  
  print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  print "<project xmlns=\"http://maven.apache.org/POM/4.0.0\"",
        " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"",
        " xsi:schemaLocation=\"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd\">"
  increment_indent()
  indent_print(as_text_only_element("modelVersion", "4.0.0"))
  
  yaml_hierarchy[1] = 0
  delete yaml_hierarchy[1]
}

# skip comments
/^[ \t\r\n]*#/ {}

# A line to add a dependency for a single group/artifact
/[ \t\r\n]*\+.*:/ {
  cur_group = ""
  start_dependency();
  
  # remove the first plus sign
  sub(/\+/, "")
  # remove any extraneous spaces
  gsub(/ /, "")

  split($0, pieces, /:/)
  print_dependency(pieces[1], pieces[2], pieces[3])
}

# A line that begins a set of artifacts under the same group
/^[ \t\r\n]*\+[^:]*/ {
  # strip + sign
  sub(/\+/, "")
  gsub(/ /, "")

  cur_group = $0
}

# A line that defines an artifact within a particular group
/^[ \t\r\n]*:/ {
  start_dependency();
  
  # clean up string
  sub(/:/, "")
  gsub(/[ \t\r\n]/, "")
  split($0, pieces, /:/)
  print_dependency(cur_group, pieces[1], pieces[2])
}

# An exclusion for a dependency
/^[ \t\r\n]*-.*:/ {
  start_exclusions()
  indent_print(as_start_element("exclusion"))
  increment_indent()
  
  # clean up string
  sub(/-/, "")
  gsub(/[ \t\r\n]/,"")  
  
  split($0, pieces, /:/)
  indent_print(as_text_only_element("groupId", pieces[1]))
  indent_print(as_text_only_element("artifactId", pieces[2]))
  
  decrement_indent()
  indent_print(as_end_element("exclusion"))
}

# Text-only (nothing embedded) elements such as "groupId: my-group"
/[^\+]*: *[^ \t\r\n]+/ {
  # replace first : with space for easy parsing
  sub(/:/," ")
  elem_name = substr($1, 1, length($1))
  indent_print(as_text_only_element(elem_name, chop_n_of_string($0, " ", 1)))
}

# Hierarchical elements, done yaml style. For instance, "build:" starts a build element that will be closed when 
# another sibling (at the same indent level) or a special-purpose item (such as a dependency) is opened.
/[^\+]*[ \t\r\n]*[^ \t\r\n]*:[ \t\r\n]*$/ {
  # figure out the number of spaces preceding the text
  text_indent = match($0, /[^ \t\r\n]/)
  spaces = substr($0, 1, text_indent -1)
  
  # now normalize $0
  gsub(/[ \t\r\n/]/, "")
  sub(/:/," ")
  
  if (spaces in hierarchy_indents) {
     # in this case, see what level of the hierarchy we're in and close out any tags as appropriate
     logical_indent = hierarchy_indents[spaces]
     close_hierarchy(yaml_hierarchy, logical_indent)
     delete_entries_longer_than(hierarchy_indents, spaces)
     
     yaml_hierarchy[logical_indent] = $1
     indent_print(as_start_element(yaml_hierarchy[logical_indent]))
     increment_indent()
  } else {
     # in this case, we need to add an item to the hierarchy     
     logical_indent = length(yaml_hierarchy) + 1
     hierarchy_indents[spaces] = logical_indent
     yaml_hierarchy[logical_indent] = $1
     
     indent_print(as_start_element(yaml_hierarchy[logical_indent]))
     increment_indent()
  }
  
}

# blank lines translate into blank lines
/^$/

# property definition lines such as a = 3
/=/ {
  start_properties()
  sub(/=/," ")
  indent_print(as_text_only_element($1, chop_n_of_string($0, " ", 1)))
}

# Force-indent lines
/->/ {
  arrow_start = match($0, /->/)
  while(arrow_start != 0) {
    increment_indent()
    $0 = substr($0, arrow_start+2)
    arrow_start = match($0, /->/)
  }
}

# Force-unindent lines
/<-/ {
  arrow_start = match($0, /<-/)
  while(arrow_start != 0) {
    decrement_indent()
    $0 = substr($0, arrow_start+2)
    arrow_start = match($0, /<-/)
  }
}

# Literal text to be copied into the pom
/```/ {
  close_properties()
  close_dependencies()
  getline line
  while(line !~ /```/) {
    indent_print(line)
    getline line
  }
}

END {
   close_properties()
   close_dependencies()
   decrement_indent()
   indent_print(as_end_element("project"))
}

