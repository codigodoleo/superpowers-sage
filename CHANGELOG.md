# Changelog

## [2.0.0](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.7.1...superpowers-sage-v2.0.0) (2026-04-18)


### ⚠ BREAKING CHANGES

* **blocks:** block architecture shifts from class-scoped (.b-{slug}) to tag-scoped custom elements (<block-{slug}>). All existing v1 blocks must be migrated via /block-refactoring.

### Features

* **agents,skills:** Wave 4 architecture features ([#24](https://github.com/codigodoleo/superpowers-sage/issues/24)) ([8de9dac](https://github.com/codigodoleo/superpowers-sage/commit/8de9dacc3d077a6949b4643d808bed9475f0bf30))
* **blocks:** adopt custom element pattern for all ACF blocks ([#20](https://github.com/codigodoleo/superpowers-sage/issues/20)) ([e124ac3](https://github.com/codigodoleo/superpowers-sage/commit/e124ac381b7a85c43eecce13ede9e83699603d11))
* **skills,ci,hooks:** Wave 3 automation helpers ([#23](https://github.com/codigodoleo/superpowers-sage/issues/23)) ([6a2930c](https://github.com/codigodoleo/superpowers-sage/commit/6a2930cc639709bef273707c84da2b8137c5a4ac))
* **skills:** add acf-block-refactor skill ([#17](https://github.com/codigodoleo/superpowers-sage/issues/17)) ([905feb7](https://github.com/codigodoleo/superpowers-sage/commit/905feb7d62dc48f4a9355bd7eb7547bd05a77a61))


### Bug Fixes

* **release:** sync version across 5 manifests and track in release-please ([#21](https://github.com/codigodoleo/superpowers-sage/issues/21)) ([0d389c9](https://github.com/codigodoleo/superpowers-sage/commit/0d389c926c0adddbad57ef55f11195303f10dcd0))


### Documentation

* **skills:** expand knowledge base with validated traps and gotchas ([#22](https://github.com/codigodoleo/superpowers-sage/issues/22)) ([1bc88d1](https://github.com/codigodoleo/superpowers-sage/commit/1bc88d19ac2fb959a1ed36d25c6078eb1fa600da))

## [1.7.1](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.7.0...superpowers-sage-v1.7.1) (2026-04-18)


### Bug Fixes

* **lang:** explicitly enforce en-US for file names and branch names ([#15](https://github.com/codigodoleo/superpowers-sage/issues/15)) ([f4b7f60](https://github.com/codigodoleo/superpowers-sage/commit/f4b7f60f8e95f014ff7cd7f41097f7698c4068f9))

## [1.7.0](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.6.0...superpowers-sage-v1.7.0) (2026-04-18)


### Features

* **lang:** enforce mandatory en-US for all artifacts and code ([#14](https://github.com/codigodoleo/superpowers-sage/issues/14)) ([610ccaa](https://github.com/codigodoleo/superpowers-sage/commit/610ccaa7f6a173997127ab0182d241c71180ceab))


### Bug Fixes

* **hooks:** quote paths and wrap with bash for Windows/VS Code ([#12](https://github.com/codigodoleo/superpowers-sage/issues/12)) ([4ef95d4](https://github.com/codigodoleo/superpowers-sage/commit/4ef95d41c94e5bcb6ef77e2fd1f73a8c9a69f020))

## [1.6.0](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.5.0...superpowers-sage-v1.6.0) (2026-04-17)


### Features

* add live Pencil screenshot with CACHED fallback to visual-verifier ([6144f17](https://github.com/codigodoleo/superpowers-sage/commit/6144f17809ff96e06be00f324cda6e09f1924ee1))
* add paper.design MCP support as preferred design source ([8a9c071](https://github.com/codigodoleo/superpowers-sage/commit/8a9c071282dfc60c14833ac3077f9d9762b4f6e3))
* add Pencil .pen path routing and workflow to designing skill ([f5533ec](https://github.com/codigodoleo/superpowers-sage/commit/f5533ecdf37ab8317709ec939666870303abfef9))
* add Pencil as step 4 in design-extractor detection order ([e41c8a1](https://github.com/codigodoleo/superpowers-sage/commit/e41c8a1ab61cba07f4d6ab18eb6adf9235f350d3))
* add Pencil MCP check and component-map.md reading to sage-architect ([dc24f15](https://github.com/codigodoleo/superpowers-sage/commit/dc24f157692fac3ccfef2b566599ada4980fa93c))
* add pencil-extractor agent (PANORAMIC/SURGICAL/COMPONENT_MAP) ([c931977](https://github.com/codigodoleo/superpowers-sage/commit/c931977376cb7e3be6cce72781e3c20ce1e947ac))
* **agents:** add paper.design source to design-extractor ([77c051c](https://github.com/codigodoleo/superpowers-sage/commit/77c051c86c7f8ae48015a16a2db0fc048857cc31))
* **agents:** add paper.design to sage-architect design tool list ([6ef9d9e](https://github.com/codigodoleo/superpowers-sage/commit/6ef9d9ebb4408b41b2d3867862bbe7967f56b33d))
* **architecture-discovery:** track paper in visual companion session ([8704f42](https://github.com/codigodoleo/superpowers-sage/commit/8704f42dff1c21b3bba33f0d766dc147a60d6280))
* **designing:** add paper.design branch with URL-based routing ([5c3f7de](https://github.com/codigodoleo/superpowers-sage/commit/5c3f7dea2ed7735f6d4285219f4bbfb98e248b3c))
* detect Pencil MCP and design/ folder in detect-design-tools ([21c47c0](https://github.com/codigodoleo/superpowers-sage/commit/21c47c085fd2cd7079d3c737d8070c145f1498b1))
* **detect:** add paper.design MCP detection with fixture tests ([53a5d3d](https://github.com/codigodoleo/superpowers-sage/commit/53a5d3dff1a6029b08d46a6458e68b59621fecbe))
* **onboarding:** detect and list paper.design MCP ([4acdb5d](https://github.com/codigodoleo/superpowers-sage/commit/4acdb5da97c99b5d4d6e67dd9c1d5874c7046e63))
* **paper-design:** implement MCP support for paper.design with URL-based routing, extraction, and verification enhancements ([e04bad4](https://github.com/codigodoleo/superpowers-sage/commit/e04bad41f865781c487cb1ca8e255297172d9aec))
* **paper.design:** add support for paper.design as a first-class design source ([08e8c03](https://github.com/codigodoleo/superpowers-sage/commit/08e8c033a73619366dbfb7f9475a30e866b6d3dc))
* **plugin:** surface paper.design MCP in hook summary and manifests ([010242e](https://github.com/codigodoleo/superpowers-sage/commit/010242e7f3517211c124f8e0cced70ec4a9c7dd7))
* **verifying:** add paper-only style spot-check vs computed_styles ([585d3b2](https://github.com/codigodoleo/superpowers-sage/commit/585d3b20274b15969d30b1f3582c62553028c71a))


### Bug Fixes

* address quality review issues in pencil-extractor agent ([dca13ec](https://github.com/codigodoleo/superpowers-sage/commit/dca13ecb33f1aa8e38a164a6128f6acb100bc6bd))
* **hooks:** add .gitattributes to force LF on shell scripts ([#9](https://github.com/codigodoleo/superpowers-sage/issues/9)) ([4fe481b](https://github.com/codigodoleo/superpowers-sage/commit/4fe481b7ea39650dcbde85ff796f4d8cb319404b))
* **manifest:** add trailing slash to skills and agents paths ([70c355e](https://github.com/codigodoleo/superpowers-sage/commit/70c355ef11b57a1eb75a60346a20df99b921f1c0))
* **manifest:** add trailing slash to skills and agents paths ([3718d40](https://github.com/codigodoleo/superpowers-sage/commit/3718d403d84d9a9beb8b0097694b4fcf534d2043))
* **manifest:** remove skills/agents/hooks path fields for auto-discovery ([#7](https://github.com/codigodoleo/superpowers-sage/issues/7)) ([bd1b2ca](https://github.com/codigodoleo/superpowers-sage/commit/bd1b2ca3b591c5174227e671d9553f5e8a4d7221))
* **marketplace:** use explicit github source for plugin resolution ([81f8b7f](https://github.com/codigodoleo/superpowers-sage/commit/81f8b7f6188be183e72c59513b5617629d1e7ab9))
* **plugin:** improve marketplace and manifest compatibility ([26be50c](https://github.com/codigodoleo/superpowers-sage/commit/26be50c23ef6ec5fc206c1af61a6138c85365ebb))


### Documentation

* add Pencil MCP support design spec ([f7636db](https://github.com/codigodoleo/superpowers-sage/commit/f7636db94933fc5f60179dba23b4999993fbae10))
* add Pencil MCP support implementation plan ([89e2d8e](https://github.com/codigodoleo/superpowers-sage/commit/89e2d8e3c2d6864b9c7219f46e619c62f953ee56))
* add Pencil MCP to README — routing, conventions, install ([f649ccd](https://github.com/codigodoleo/superpowers-sage/commit/f649ccd257a33ae44f0faa9c89c0f481199ef758))
* **designing:** update purpose line to reflect paper + URL routing ([2154812](https://github.com/codigodoleo/superpowers-sage/commit/2154812d3669ad5104d22fbf9df0d659fa974ce3))
* **readme:** add agnostic installation guide for Claude, VS Code, Cursor ([3e86691](https://github.com/codigodoleo/superpowers-sage/commit/3e86691e77501fe88e5f2208af1425203a1e5699))
* **readme:** document paper.design MCP as preferred design source ([23b4643](https://github.com/codigodoleo/superpowers-sage/commit/23b46432072921373dd22d2f9f843177bbcdd157))
* revise sage-design-system spec and plan ([26095ae](https://github.com/codigodoleo/superpowers-sage/commit/26095ae0f1a7793ff4d9f471aa7af801eb550017))
* **sageing:** document paper.design as preferred design source ([23beee3](https://github.com/codigodoleo/superpowers-sage/commit/23beee31a2bbb6b378d0dc631c05295918090a06))

## [1.4.3](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.4.2...superpowers-sage-v1.4.3) (2026-04-14)


### Bug Fixes

* **hooks:** add .gitattributes to force LF on shell scripts ([#9](https://github.com/codigodoleo/superpowers-sage/issues/9)) ([4fe481b](https://github.com/codigodoleo/superpowers-sage/commit/4fe481b7ea39650dcbde85ff796f4d8cb319404b))

## [1.4.2](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.4.1...superpowers-sage-v1.4.2) (2026-04-14)


### Bug Fixes

* **manifest:** remove skills/agents/hooks path fields for auto-discovery ([#7](https://github.com/codigodoleo/superpowers-sage/issues/7)) ([bd1b2ca](https://github.com/codigodoleo/superpowers-sage/commit/bd1b2ca3b591c5174227e671d9553f5e8a4d7221))

## [1.4.1](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.4.0...superpowers-sage-v1.4.1) (2026-04-14)


### Bug Fixes

* **manifest:** add trailing slash to skills and agents paths ([70c355e](https://github.com/codigodoleo/superpowers-sage/commit/70c355ef11b57a1eb75a60346a20df99b921f1c0))
* **manifest:** add trailing slash to skills and agents paths ([3718d40](https://github.com/codigodoleo/superpowers-sage/commit/3718d403d84d9a9beb8b0097694b4fcf534d2043))

## [1.4.0](https://github.com/codigodoleo/superpowers-sage/compare/superpowers-sage-v1.3.0...superpowers-sage-v1.4.0) (2026-04-14)


### Features

* add paper.design MCP support as preferred design source ([8a9c071](https://github.com/codigodoleo/superpowers-sage/commit/8a9c071282dfc60c14833ac3077f9d9762b4f6e3))
* **agents:** add paper.design source to design-extractor ([77c051c](https://github.com/codigodoleo/superpowers-sage/commit/77c051c86c7f8ae48015a16a2db0fc048857cc31))
* **agents:** add paper.design to sage-architect design tool list ([6ef9d9e](https://github.com/codigodoleo/superpowers-sage/commit/6ef9d9ebb4408b41b2d3867862bbe7967f56b33d))
* **architecture-discovery:** track paper in visual companion session ([8704f42](https://github.com/codigodoleo/superpowers-sage/commit/8704f42dff1c21b3bba33f0d766dc147a60d6280))
* **designing:** add paper.design branch with URL-based routing ([5c3f7de](https://github.com/codigodoleo/superpowers-sage/commit/5c3f7dea2ed7735f6d4285219f4bbfb98e248b3c))
* **detect:** add paper.design MCP detection with fixture tests ([53a5d3d](https://github.com/codigodoleo/superpowers-sage/commit/53a5d3dff1a6029b08d46a6458e68b59621fecbe))
* **onboarding:** detect and list paper.design MCP ([4acdb5d](https://github.com/codigodoleo/superpowers-sage/commit/4acdb5da97c99b5d4d6e67dd9c1d5874c7046e63))
* **paper-design:** implement MCP support for paper.design with URL-based routing, extraction, and verification enhancements ([e04bad4](https://github.com/codigodoleo/superpowers-sage/commit/e04bad41f865781c487cb1ca8e255297172d9aec))
* **paper.design:** add support for paper.design as a first-class design source ([08e8c03](https://github.com/codigodoleo/superpowers-sage/commit/08e8c033a73619366dbfb7f9475a30e866b6d3dc))
* **plugin:** surface paper.design MCP in hook summary and manifests ([010242e](https://github.com/codigodoleo/superpowers-sage/commit/010242e7f3517211c124f8e0cced70ec4a9c7dd7))
* **verifying:** add paper-only style spot-check vs computed_styles ([585d3b2](https://github.com/codigodoleo/superpowers-sage/commit/585d3b20274b15969d30b1f3582c62553028c71a))


### Bug Fixes

* **marketplace:** use explicit github source for plugin resolution ([81f8b7f](https://github.com/codigodoleo/superpowers-sage/commit/81f8b7f6188be183e72c59513b5617629d1e7ab9))
* **plugin:** improve marketplace and manifest compatibility ([26be50c](https://github.com/codigodoleo/superpowers-sage/commit/26be50c23ef6ec5fc206c1af61a6138c85365ebb))


### Documentation

* **designing:** update purpose line to reflect paper + URL routing ([2154812](https://github.com/codigodoleo/superpowers-sage/commit/2154812d3669ad5104d22fbf9df0d659fa974ce3))
* **readme:** add agnostic installation guide for Claude, VS Code, Cursor ([3e86691](https://github.com/codigodoleo/superpowers-sage/commit/3e86691e77501fe88e5f2208af1425203a1e5699))
* **readme:** document paper.design MCP as preferred design source ([23b4643](https://github.com/codigodoleo/superpowers-sage/commit/23b46432072921373dd22d2f9f843177bbcdd157))
* **sageing:** document paper.design as preferred design source ([23beee3](https://github.com/codigodoleo/superpowers-sage/commit/23beee31a2bbb6b378d0dc631c05295918090a06))
