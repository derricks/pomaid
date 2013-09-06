pomaid
======
pomaid is a tool that allows a more concise format for Maven pom.xml files. It's inspired by [this article about "Invisible XML"](http://www.balisage.net/Proceedings/vol10/html/Pemberton01/BalisageVol10-Pemberton01.html?utm_source=statuscode&utm_medium=email)

`
Usage: awk -f pomaid_to_pom.awk pomaid_file
`

Syntax:

Text-only XML elements
----------------------
    elem_name: elem_value

Creates an entry of the form `<elem_name>elem_value</elem_name>`

Properties
----------
    prop_name = prop_value

Creates a `<property>` element of the form `<prop_name>prop_value</prop_name>`. `<property>` elements will be embedded inside a `<properties>` element.
    
Dependencies
------------
Whenever a dependency is created, the corresponding `</dependency>` element will not be created until a new dependency is spotted. Thus, any line created after a dependency and before a new one will be folded into the top dependency. See below for an example.

### One-off dependency
    + group_id:artifact_id:version

Adds a dependency on a library with the relevant group\_id, artifact\_id, and optional version. version is optional because many projects list all dependencies (with version) in a top-level pom and then reference them in submodules.

### Multiple dependencies for a shared group
You can combine multiple dependencies for the same group.

    + group_id
       :artifact_1_id:version
       :artifact_2_id:version

### Exclusions
    - group_id:artifact_id

Adds an exclusion for the previously-referenced dependency.

### Dependency Example
The following example comes from a pomaid version of a [Spring pom.xml from the Internet](http://repo1.maven.org/maven2/org/springframework/spring-webmvc/3.2.4.RELEASE/spring-webmvc-3.2.4.RELEASE.pom) and illustrates the ideas above.

    + org.apache.tiles
      :tiles-api:3.0.1
        scope: compile
        optional: true
      :tiles-core:3.0.1
        scope: compile
        optional: true
        - org.slf4j:jcl-over-slf4j

The first line starts a set of dependencies all in the same group. The second line adds one of the specific artifacts within the group. The `scope` and `optional` lines will add the appropriate values to the tiles-api dependency. The tiles-core dependency is similar, but it also includes an exclusion of org.slf4j:jcl-over-slf4j. This will be applied to the tiles-core dependency, not the tiles-api dependency.

Arbitrary Hierarchy
-------------------
pom.xml files often have a variety of nested elements that aren't easily abstracted into a specialized syntax, so pomaid support yaml-style elements that translate into start/end elements in the pom.xml. yaml means that siblings within a hierarchy must have consistent spacing from the edge.

### Example
Again, taken from a pomaid version of the Spring MVC pom.xml.

    licenses:
      license:
        name: The Apache Software License, Version 2.0
        url:http://www.apache.org/licenses/LICENSE-2.0.txt
        distribution:repo

    developers:
      developer:
        id:jhoeller
        name: Juergen Hoeller
        email:jhoeller@vmware.com
    
Literal Text
------------
Rather than support every conceivable Maven directive, pomaid lets you define text inline that is copied directly to the output.

    ```
    text
    ```

Copies the text as-is into the output. No processing is done on these lines.

### Adjusting Indents
Because no processing is done on literal text lines, any indents that occur in that text will be ignored. If you have a mix of literal text and pomaid instructions and you want proper indenting, you need to tell pomaid how to adjust its current indent level.

    ->

Forces the printing indent to be increased by 1. Multiple arrows on a line will cause that many indent adjustments.

    <-

Forces the printing indent to be decreased by 1. Multiple arrows on a line will cause that many indent adjustments.


### Example
This is again copied from the pomaid version of the Spring pom.xml file, and mixes literal text with pomaid "name: value" instructions.

    ```
    <organization>
    ```
    ->
      name: SpringSource
      url: http://springsource.org/spring-framework
    <-
    ```
    </organization>
    <licenses>
      <license>
    ```
    -> ->
    name: The Apache Software License, Version 2.0
    url:http://www.apache.org/licenses/LICENSE-2.0.txt
    distribution:repo
    <- <-

Comments
--------
Lines prefixed with # are ignored.

Blank Lines
-----------
Blank lines in the pomaid file will be copied into the output. Note, however, that the rules about adding to dependencies still apply: You may find that a blank line is inserted _before_ the `</dependency>` line.