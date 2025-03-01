---
title: SHOW TRANSACTION statement [YSQL]
headerTitle: SHOW TRANSACTION
linkTitle: SHOW TRANSACTION
description: Use the SHOW TRANSACTION statement to show the current transaction isolation level.
summary: SHOW TRANSACTION
menu:
  preview:
    identifier: txn_show
    parent: statements
aliases:
  - /preview/api/ysql/commands/txn_show/
isTocNested: true
showAsideToc: true
---

## Synopsis

Use the `SHOW TRANSACTION` statement to show the current transaction isolation level.

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
  {{% includeMarkdown "../../syntax_resources/the-sql-language/statements/show_transaction.grammar.md" %}}
  </div>
  <div id="diagram" class="tab-pane fade" role="tabpanel" aria-labelledby="diagram-tab">
  {{% includeMarkdown "../../syntax_resources/the-sql-language/statements/show_transaction.diagram.md" %}}
  </div>
</div>

## Semantics

Supports Serializable, Snapshot and Read Committed Isolation<sup>$</sup> using the PostgreSQL isolation level syntax of `SERIALIZABLE`, `REPEATABLE READ` and `READ COMMITTED` respectively. PostgreSQL's `READ UNCOMMITTED` also maps to Read Committed Isolation.

<sup>$</sup> Read Committed Isolation is supported only if the gflag `yb_enable_read_committed_isolation` is set to `true`. By default this gflag is `false` and in this case the Read Committed isolation level of Yugabyte's transactional layer falls back to the stricter Snapshot Isolation (in which case `READ COMMITTED` and `READ UNCOMMITTED` of YSQL also in turn use Snapshot Isolation). Read Committed support is currently in [Beta](/preview/faq/general/#what-is-the-definition-of-the-beta-feature-tag).

### TRANSACTION ISOLATION LEVEL

Show the current transaction isolation level.

The `TRANSACTION ISOLATION LEVEL` returned is either `SERIALIZABLE`, `REPEATABLE READ`, `READ COMMITTED` or `READ UNCOMMITTED`.

## See also

- [`SET TRANSACTION`](../txn_set)
- [`Transaction isolation levels`](../../../../../architecture/transactions/isolation-levels)
