---
title: DROP GROUP statement [YSQL]
linkTitle: DROP GROUP
description: Use the DROP GROUP statement to drop a role. DROP GROUP is an alias for DROP ROLE and is used to drop a role.
menu:
  v2.8:
    identifier: dcl_drop_group
    parent: statements
isTocNested: true
showAsideToc: true
---

## Synopsis

Use the `DROP GROUP` statement to drop a role. `DROP GROUP` is an alias for [`DROP ROLE`](../dcl_drop_role) and is used to drop a role.

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
  {{% includeMarkdown "../../syntax_resources/the-sql-language/statements/drop_group.grammar.md" %}}
  </div>
  <div id="diagram" class="tab-pane fade" role="tabpanel" aria-labelledby="diagram-tab">
  {{% includeMarkdown "../../syntax_resources/the-sql-language/statements/drop_group.diagram.md" %}}
  </div>
</div>

## Semantics

See [`DROP ROLE`](../dcl_drop_role) for more details.

## Example

- Drop a group.

```plpgsql
yugabyte=# DROP GROUP SysAdmin;
```

## See also

- [`CREATE ROLE`](../dcl_create_role)
- [`ALTER ROLE`](../dcl_alter_role)
- [`GRANT`](../dcl_grant)
- [`REVOKE`](../dcl_revoke)
