# Postmortem Index

Documenting incidents, failures, and lessons learned during infrastructure lab development.

## Purpose

Postmortems serve multiple purposes:
1. **Learning:** Understand what went wrong and why
2. **Prevention:** Identify concrete actions to prevent recurrence  
3. **Knowledge sharing:** Help others avoid similar mistakes
4. **Interview material:** Demonstrate mature incident response thinking

## Format

Each postmortem follows SRE best practices:
- Blameless (focus on systems, not people)
- Actionable (specific prevention items)
- Timely (written soon after incident)
- Reviewed (lessons actually implemented)

## Incidents

### Critical Severity

**001** - [Network Configuration Lockout](001-network-lockout.md)  
*Date: 2025-01-19 | Duration: 8 hours | Impact: Complete system loss*  
Applied untested network config to live system, lost SSH access, recovered via rebuild.

---

## Severity Definitions

**Critical:** Complete loss of system access or functionality  
**High:** Major functionality impaired, workarounds exist  
**Medium:** Degraded performance or partial functionality loss  
**Low:** Minor issues with minimal impact  

## Postmortem Template

For future incidents, use: `postmortems/TEMPLATE.md`
