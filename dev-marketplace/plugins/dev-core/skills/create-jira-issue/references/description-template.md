# Jira Issue Description Template

This template provides a standard structure for creating well-organized Jira issue descriptions.

## Standard Template Structure

### Why
Explain the motivation and value proposition:
- Business value or problem being solved
- User impact or pain points addressed
- Strategic alignment or long-term benefits
- Technical debt reduction or infrastructure improvements

### What
Describe what will be built or changed:
- High-level overview of the solution (2-3 sentences)
- Key technologies or approaches being used
- Expected deliverables or outcomes

**Tech Stack** (if applicable):
- List key technologies, frameworks, or tools
- Specify versions if important
- Note any specific configurations

### Scope
Define what is included in this work:
- Specific features or functionality to be implemented
- Infrastructure or environment setup
- Testing and validation activities
- Documentation deliverables
- Any measurements or benchmarks to be performed

**Success Criteria** (use checkboxes):
- [ ] Measurable outcome 1
- [ ] Measurable outcome 2
- [ ] Measurable outcome 3

### Out of Scope
Explicitly state what is NOT included:
- Features or functionality deferred to future work
- Environments not covered (e.g., production deployment)
- Advanced features or optimizations
- Integration with other systems
- Any clarifications to prevent scope creep

## Usage Guidelines

1. **Adapt to Issue Type**: Not all sections are required for every issue type
   - Epics: Use all sections for comprehensive planning
   - Stories: Focus on Why, What, and Success Criteria
   - Tasks: May only need What and Scope
   - Bugs: Replace Why with "Problem Description", What with "Root Cause"

2. **Be Specific**: Avoid vague statements
   - Good: "API response time under 200ms for 95th percentile"
   - Bad: "Make it faster"

3. **Use Checkboxes for Tracking**: Success Criteria should be actionable and measurable

4. **Link Related Issues**: Reference related Epics, Stories, or dependencies using issue keys

5. **Keep It Concise**: Each section should be 2-5 bullet points or 1-2 short paragraphs
