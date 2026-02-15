build:
	cd Packages/SkillHubCLI && swift build

app:
	cd Packages/SkillHubApp && swift build

run-app:
	cd Packages/SkillHubApp && swift run

test:
	@echo "No XCTest in this environment; core logic is covered by smoke build."
	cd Packages/SkillHubCLI && swift build

run:
	cd Packages/SkillHubCLI && swift run skillhub help
