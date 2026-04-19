# Reference File Contract (superpowers-sage)

Every `references/*.md` file in a skill MUST follow this structure:

1. **Line 1**: Loader note — `Deep reference for <topic>. Loaded on demand from \`skills/<name>/SKILL.md\`.`
2. **Line 2**: Blank
3. **Line 3**: H1 title — `# <Title>`
4. **Line 4**: Blank
5. **Line 5**: One-sentence intro — describes what this reference covers and when to read it.
6. **Line 6**: Blank
7. **Line 7+**: First `## ` section heading

Constraints:
- No code before line 7.
- One-sentence intro must stand alone (not be a heading).
- Reference must make sense read in isolation from SKILL.md.
