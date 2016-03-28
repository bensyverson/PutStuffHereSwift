import PackageDescription

let package = Package(
    name: "PutStuffHere",
	dependencies: [
		.Package(url: "https://github.com/IBM-Swift/Kitura-TemplateEngine", majorVersion: 0, minor: 0)
	]
)
