---
title: CREATE FOREIGN DATA WRAPPER statement [YSQL]
headerTitle: CREATE FOREIGN DATA WRAPPER
linkTitle: CREATE FOREIGN DATA WRAPPER
description: Use the CREATE FOREIGN DATA WRAPPER statement to create a foreign-data wrapper.
menu:
  preview:
    identifier: ddl_create_foreign_data_wrapper
    parent: statements
isTocNested: true
showAsideToc: true
---

## Synopsis

Use the `CREATE FOREIGN DATA WRAPPER` statement to create a foreign data wrapper.
Only superusers or users with the yb_fdw role can create foreign data wrappers.


## Syntax

<ul class="nav nav-tabs nav-tabs-yb">
  <li >
    <a href="#grammar" class="nav-link active" id="grammar-tab" data-toggle="tab" role="tab" aria-controls="grammar" aria-selected="true">
      <i class="fas fa-file-alt" aria-hidden="true"></i>
      Grammar
    </a>
  </li>
  <li>
    <a href="#diagram" class="nav-link" id="diagram-tab" data-toggle="tab" role="tab" aria-controls="diagram" aria-selected="false">
      <i class="fas fa-project-diagram" aria-hidden="true"></i>
      Diagram
    </a>
  </li>
</ul>

<div class="tab-content">
  <div id="grammar" class="tab-pane fade show active" role="tabpanel" aria-labelledby="grammar-tab">
  {{% includeMarkdown "../../syntax_resources/the-sql-language/statements/create_foreign_data_wrapper.grammar.md" %}}
  </div>
  <div id="diagram" class="tab-pane fade" role="tabpanel" aria-labelledby="diagram-tab">
  {{% includeMarkdown "../../syntax_resources/the-sql-language/statements/create_foreign_data_wrapper.diagram.md" %}}
  </div>
</div>

## Semantics

Create a FDW named *fdw_name*.

### Handler function
The *handler_function* will be called to retrieve the execution functions for foreign tables. These functions are required by the planner and executor.
The handler function takes no arguments and its return type should be `fdw_handler`.
If no handler function is provided, foreign tables that use the wrapper can only be declared (and not accessed).

### Validator function

The *validator_function* is used to validate the options given to the foreign-data wrapper, and the foreign servers, user mappings and foreign tables that use the foreign-data wrapper.
The validator function takes two arguments: a text array (type text[]) that contains the options to be validated, and an OID of the system catalog that the object associated with the options is stored in.
If no validator function is provided (or `NO VALIDATOR` is specified), the options will not be checked at the time of creation.

### Options:
The `OPTIONS` clause specifies options for the foreign-data wrapper. The permitted option names and values are specific to each foreign data wrapper. The options are validated using the FDW’s validator function.

## Examples

Basic example.

```plpgsql
yugabyte=# CREATE FOREIGN DATA WRAPPER my_wrapper HANDLER myhandler OPTIONS (dummy 'true');
```

## See also

- [`CREATE FOREIGN TABLE`](../ddl_create_foreign_table/)
- [`CREATE SERVER`](../ddl_create_server/)
- [`CREATE USER MAPPING`](../ddl_create_user_mapping/)
- [`IMPORT FOREIGN SCHEMA`](../ddl_import_foreign_schema/)
- [`ALTER FOREIGN DATA WRAPPER`](../ddl_alter_foreign_data_wrapper/)
- [`DROP FOREIGN DATA WRAPPER`](../ddl_drop_foreign_data_wrapper/)