# Fallacy Catalog

## Overview

This catalog defines 22 logical fallacies that agents must detect and flag during analysis. Each entry includes a detection heuristic and a software engineering example. Used primarily by Eris (Devil's Advocate) and Athena (Semantic Evaluator).

---

## Causal Fallacies

### 1. Post Hoc Ergo Propter Hoc (사후 귀인 오류)

**Description:** Assuming that because event B followed event A, A caused B.

**Detection heuristic:** Look for claims where temporal sequence is the only evidence for causation. Flag statements like "after we did X, Y happened, therefore X caused Y" without controlled comparison.

**Software engineering example:** "We deployed the new cache layer on Monday and response times improved on Tuesday, so the cache fixed performance." (Ignoring that a CDN configuration also changed Monday night.)

---

### 2. Correlation != Causation (상관-인과 혼동)

**Description:** Treating a statistical correlation as proof of a causal relationship.

**Detection heuristic:** Flag claims that use correlation data (co-occurrence, trend similarity) as sole evidence for causation without mechanism explanation.

**Software engineering example:** "Modules with more comments have fewer bugs, so we should add more comments to reduce bugs." (High-quality code may independently lead to both more comments and fewer bugs.)

---

### 3. Single Cause Fallacy (단일 원인 오류)

**Description:** Attributing an outcome to a single cause when multiple factors contribute.

**Detection heuristic:** Flag root-cause analyses that identify exactly one cause for a complex failure without exploring contributing factors.

**Software engineering example:** "The outage was caused by the database migration script." (Ignoring that the monitoring gap, missing rollback plan, and load spike all contributed.)

---

### 4. Slippery Slope (미끄러운 비탈길 논증)

**Description:** Arguing that a small first step will inevitably lead to extreme consequences without justifying the chain.

**Detection heuristic:** Look for chains of "if X then Y then Z" where intermediate steps lack evidence of inevitability.

**Software engineering example:** "If we allow one exception to the coding standard, soon nobody will follow any standards and the codebase will become unmaintainable."

---

## Evidence Fallacies

### 5. Cherry Picking (편향적 증거 선택)

**Description:** Selecting only evidence that supports a conclusion while ignoring contradictory evidence.

**Detection heuristic:** Check if the analysis considered counter-examples or opposing data points. Flag when only favorable metrics are presented.

**Software engineering example:** "Our microservice architecture is superior -- look at these three services with 99.99% uptime." (Ignoring five other services with frequent failures.)

---

### 6. Survivorship Bias (생존자 편향)

**Description:** Drawing conclusions only from successful cases, ignoring failures that are no longer visible.

**Detection heuristic:** Flag analyses that study only existing/successful entities without accounting for those that failed or were removed.

**Software engineering example:** "All our production services use Pattern X, so Pattern X is the best approach." (Ignoring that services using Pattern X that failed were decommissioned.)

---

### 7. Anecdotal Evidence (일화적 증거)

**Description:** Using personal experience or isolated examples as sufficient evidence for a general claim.

**Detection heuristic:** Flag claims supported only by "in my experience" or single-instance stories rather than systematic data.

**Software engineering example:** "I once saw a project fail because of microservices, so monoliths are always better for our scale."

---

### 8. Appeal to Authority (권위에의 호소)

**Description:** Accepting a claim as true because an authority figure endorses it, without evaluating the evidence.

**Detection heuristic:** Flag arguments whose primary support is "X says so" or "according to [famous person]" without technical justification.

**Software engineering example:** "We should use event sourcing because Martin Fowler recommends it." (Without analyzing whether it fits the specific use case.)

---

### 9. Hasty Generalization (성급한 일반화)

**Description:** Drawing a broad conclusion from a small or unrepresentative sample.

**Detection heuristic:** Flag conclusions drawn from fewer than 3 data points or from a non-representative subset.

**Software engineering example:** "We tested the API with 2 requests and both were fast, so performance is not a concern." (No load testing performed.)

---

## Reasoning Fallacies

### 10. Straw Man (허수아비 논증)

**Description:** Misrepresenting an argument to make it easier to attack.

**Detection heuristic:** Compare the original claim with the version being criticized. Flag if the criticized version is a distorted or extreme version of the original.

**Software engineering example:** Original: "We should consider adding type hints." Straw man: "They want us to rewrite the entire codebase in a statically-typed language."

---

### 11. False Dilemma (거짓 딜레마)

**Description:** Presenting only two options when more exist.

**Detection heuristic:** Flag "either A or B" framings. Check whether alternatives C, D, etc. are viable but unmentioned.

**Software engineering example:** "We either rewrite the system from scratch or live with the technical debt forever." (Ignoring incremental refactoring.)

---

### 12. Circular Reasoning (순환 논증)

**Description:** Using the conclusion as a premise in the argument.

**Detection heuristic:** Check if the justification for a claim restates the claim in different words.

**Software engineering example:** "This design is the best because it is the optimal solution." (The justification is the claim itself.)

---

### 13. Moving Goalposts (골대 이동)

**Description:** Changing the criteria for success after the evidence has been presented.

**Detection heuristic:** Track stated acceptance criteria over time. Flag if criteria change after evidence meeting the original criteria is provided.

**Software engineering example:** "The feature needs 80% test coverage." After achieving 82%: "Actually, we need 95% and integration tests too."

---

### 14. Red Herring (훈제 청어)

**Description:** Introducing an irrelevant topic to divert attention from the original issue.

**Detection heuristic:** Check if a response actually addresses the original question or concern. Flag tangential discussions that do not resolve the core issue.

**Software engineering example:** During a discussion about API security: "But have you seen how slow the CI pipeline is? We should fix that first."

---

### 15. Tu Quoque (피장파장)

**Description:** Deflecting criticism by pointing out that the critic does the same thing.

**Detection heuristic:** Flag responses to criticism that focus on the critic's behavior rather than addressing the substance.

**Software engineering example:** "You say our code lacks tests, but your team's module has even fewer tests."

---

## Premise Fallacies

### 16. Begging the Question (논점 선취)

**Description:** Assuming the truth of the conclusion within the premises.

**Detection heuristic:** Check if any premise is logically equivalent to the conclusion.

**Software engineering example:** "We need a NoSQL database because relational databases cannot handle our data." (Assumes the conclusion that relational databases are insufficient without proving it.)

---

### 17. False Analogy (거짓 유추)

**Description:** Comparing two things that are not sufficiently similar to support the conclusion.

**Detection heuristic:** When an analogy is used, list the relevant similarities and differences. Flag if differences outweigh or undermine the similarities.

**Software engineering example:** "Building software is like building a house -- you need a complete blueprint before starting construction." (Software is iterative; houses are not easily refactored.)

---

### 18. Composition/Division (합성/분할의 오류)

**Description:** Assuming what is true of the parts is true of the whole (composition), or vice versa (division).

**Detection heuristic:** Flag claims that attribute properties of individual components to the system, or system properties to individual components.

**Software engineering example:** Composition: "Each microservice is fast, so the system as a whole will be fast." (Ignoring network latency between services.) Division: "The system handles 10K RPS, so each service must handle 10K RPS."

---

### 19. Appeal to Nature (자연에의 호소)

**Description:** Arguing that something is good because it is "natural" or bad because it is "unnatural."

**Detection heuristic:** Flag arguments that use "natural," "organic," "the way things should be" as justification without technical merit.

**Software engineering example:** "Monorepos are the natural way to organize code -- that is how it was done originally." (Historical precedent is not a technical argument.)

---

### 20. No True Scotsman (참된 스코틀랜드인 없음)

**Description:** Redefining criteria to exclude counter-examples rather than accepting them.

**Detection heuristic:** Flag when a counter-example is dismissed by narrowing the definition rather than addressing it.

**Software engineering example:** "No well-architected system has this problem." When shown one: "That system is not truly well-architected."

---

### 21. Sunk Cost Fallacy (매몰 비용 오류)

**Description:** Continuing an endeavor because of previously invested resources rather than future value.

**Detection heuristic:** Flag justifications that reference past investment ("we have already spent X months on this") rather than future ROI.

**Software engineering example:** "We cannot switch frameworks now -- we have already spent 6 months building on this one." (Without evaluating if continuing costs more than switching.)

---

### 22. Bandwagon Fallacy (편승 오류)

**Description:** Arguing something is correct or good because many people do it or believe it.

**Detection heuristic:** Flag arguments whose primary justification is popularity or adoption rate without technical evaluation.

**Software engineering example:** "Everyone is using Kubernetes, so we should too." (Without evaluating if the team's scale and needs warrant it.)
