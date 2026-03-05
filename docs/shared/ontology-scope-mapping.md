# Ontology Scope Mapping Protocol

## Overview

This protocol defines Prism's 5-step process for constructing the ontology source pool. The ontology pool is the collection of data sources that analysts will consult during multi-perspective analysis. It ensures that all relevant sources are discovered, selected, and made accessible before analysis begins.

## Step 1: MCP Discovery

**Objective:** Automatically discover all available MCP data sources.

**Actions:**
1. Call `ListMcpResourcesTool` to enumerate all MCP resources currently available in the environment.
2. Call `ToolSearch` to find additional data-fetching tools that may provide relevant information.
3. Catalog all discovered sources with:
   - Source name
   - Source type (MCP resource, tool, file, URL)
   - Access method (tool name, resource URI)
   - Brief description of what data it provides

**Output:** A catalog of all automatically discoverable sources.

## Step 2: Source Selection

**Objective:** Let the user select which discovered sources are relevant.

**Actions:**
1. Present the discovered source catalog to the user via `AskUserQuestion`.
2. Format as a multi-select list with descriptions.
3. User selects relevant sources by number or name.

**Output:** A filtered list of user-approved sources.

## Step 3: External Source Addition (Loop)

**Objective:** Allow the user to add sources not automatically discovered.

**Actions:**
1. Ask the user via `AskUserQuestion`: "Do you have additional sources to add? Provide a URL, file path, or type 'done' to finish."
2. If URL provided: Fetch the content and add to the catalog.
3. If file path provided: Read the file and add to the catalog.
4. If 'done': Exit the loop.
5. Repeat until the user types 'done'.

**Output:** Extended source catalog including user-provided sources.

## Step 4: Pool Confirmation

**Objective:** Get final confirmation on the complete source pool.

**Actions:**
1. Present the final combined pool (auto-discovered + user-selected + user-added) via `AskUserQuestion`.
2. Offer options:
   - **Proceed** -- Accept the pool and begin analysis
   - **Reselect** -- Go back to Step 2 and reselect from discovered sources
   - **Add more** -- Go back to Step 3 and add more external sources
   - **Cancel** -- Abort the ontology scope mapping

**Output:** Confirmed source pool.

## Step 5: Scope Block Generation

**Objective:** Generate scope instruction blocks for analyst and devil's advocate agents.

### ontology-scope-analyst.md

Generated for analyst agents. Contains:
- Complete source list with access instructions for each source
- Directive: "You MUST consult these sources during your analysis. Reference specific data from these sources in your findings."
- For each source: name, type, access method, and what to look for

### ontology-scope-da.md

Generated for Eris (Devil's Advocate). Contains:
- Same source list as the analyst scope
- Verification mission: "Your job is to verify that analysts actually consulted these sources and that their claims are supported by the data."
- Checklist for each source:
  - [ ] Source was referenced in analyst findings
  - [ ] Claims citing this source are accurate
  - [ ] No contradictory evidence from this source was ignored

## Soft Dependency: No MCP Resources

If no MCP resources are available in the environment:
- **Skip Steps 1 and 2** entirely.
- **Proceed directly to Step 3** (External Source Addition).
- The user provides all sources manually.
- Steps 4 and 5 proceed as normal.
