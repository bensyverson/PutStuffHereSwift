import Foundation
import KituraTemplateEngine

public protocol ParentheticalDelegate {
	func render(value: Any, parenthetical: String) -> String
}

enum PutErrorsHere : ErrorType {
	case FileReadError
}

enum Parentheticals : String {
	case Unescaped = "unescaped"
}

private class TemplateComponent {
	
}

private class TemplateString : TemplateComponent {
	let string : String
	init(string: String) {
		self.string = string
	}
}

private class TemplateVariable : TemplateComponent {
	let variable : String
	let parenthetical : String?
	init(variable: String, parenthetical: String?) {
		self.variable = variable
		self.parenthetical = parenthetical
	}
}

private class SimpleTemplate {
	let components : [TemplateComponent]
	init(components: [TemplateComponent]) {
		self.components = components
	}
	
	func render(context: [String: Any], delegate: ParentheticalDelegate?) -> String {
		return "Unimplemented."
	}
}

private class HTMLTemplate : SimpleTemplate {
	override func render(context: [String: Any], delegate: ParentheticalDelegate?) -> String {
		return components.map{
			(component) -> String in
			switch component {
			case let aString as TemplateString:
				return aString.string
			case let aVar as TemplateVariable:
				guard let aValue = context[aVar.variable] else {
					// If there is no value in the context, return an empty string.
					return ""
				}
				if let aParenthetical = aVar.parenthetical {
					if aParenthetical == Parentheticals.Unescaped.rawValue {
						return stringify(aValue)
					} else if let aDelegate = delegate  {
						return aDelegate.render(aValue, parenthetical: aParenthetical)
					}
				}
				return escapeHTML(stringify(aValue))
			default:
				return "Unknown component type."
			}
		}.reduce("", combine:+) // concatenate the components
	}
}

private func stringify(thing: Any) -> String {
	switch thing {
	case let aString as String:
		return aString
	default:
		return "\(thing)"
	}
}

private func escapeHTML(html: String) -> String {
	return html.stringByReplacingOccurrencesOfString("___•••amp•••___", withString:"")
		.stringByReplacingOccurrencesOfString("&",  withString:"___•••amp•••___")
		.stringByReplacingOccurrencesOfString("<",  withString:"&lt;")
		.stringByReplacingOccurrencesOfString(">",  withString:"&gt;")
		.stringByReplacingOccurrencesOfString("'",  withString:"&apos;")
		.stringByReplacingOccurrencesOfString("\"", withString:"&quot;")
		.stringByReplacingOccurrencesOfString("___•••amp•••___", withString:"&amp;")
}

func matchesForRegexInText(regex: NSRegularExpression, text: String) -> [String] {
	let nsString = text as NSString
	let results = regex.matchesInString(text,
										options: [], range: NSMakeRange(0, nsString.length))
	return results.map { nsString.substringWithRange($0.range)}
}

public class PutStuffHere : TemplateEngine {
	var parentheticalDelegate : ParentheticalDelegate? = nil
	
	var shouldExtractBody = true
	// The main regex. This can and should be extended with other syntaxes.
	private let regex = try! NSRegularExpression(pattern: "([\\s\\W]|^)(?:(?:put|insert)\\s+(.+?\\S)(?:\\s*\\(([^)]+)\\))?\\s+here)([\\W\\s]|$)", options: [.CaseInsensitive])

	private var templates : [String : SimpleTemplate] = [:]
	
	public init(){
	}
	
	// protocol getter
	public var fileExtension : String {
		get {
			return "html"
		}
	}
	// protocol method
	public func render(filePath: String, context: [String: Any]) throws -> String {
		if templates[filePath] == nil {
			let rawString = try String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding)
			let innerString = shouldExtractBody ? extractBody(rawString) : rawString
			templates[filePath] = HTMLTemplate(components: parseComponents(innerString))
		}
		
		guard let template = templates[filePath] else {
			throw PutErrorsHere.FileReadError
		}
		return template.render(context, delegate: parentheticalDelegate)
	}
	
	
	
	private func getLocalRegex() -> NSRegularExpression {
		return regex
	}
	
	private func parseComponents(text: String) -> [TemplateComponent] {
		let localRegex = getLocalRegex()
		
		let nsString = text as NSString
		let results = localRegex.matchesInString(text, options: [], range: NSMakeRange(0, nsString.length))
		
		var lastIndex = 0
		var components : [TemplateComponent] = []
		
		for (_, result) in results.enumerate(){
			let p0 = result.rangeAtIndex(0)
			let p2 = result.rangeAtIndex(2)
			let p3 = result.rangeAtIndex(3)
			
			let parenthetical : String? = (p3.location != Foundation.NSNotFound) ?  nsString.substringWithRange(p3) : nil
			
			if (p0.location + 1) > lastIndex {
				components.append(TemplateString(string: nsString.substringWithRange(NSRange(location:lastIndex, length: (p0.location - lastIndex) + 1))))
			}
			components.append(TemplateVariable(variable:nsString.substringWithRange(p2), parenthetical: parenthetical))
			lastIndex = (p0.location + p0.length) - 1
		}
		if lastIndex < (nsString.length - 1) {
			components.append(TemplateString(string: nsString.substringWithRange(NSRange(location:lastIndex, length: nsString.length - lastIndex))))
		}
		return components
	}
	
	private func extractBody(html: String) -> String {
		if html.containsString("<body") {
			let openTag = try! NSRegularExpression(pattern: "^.*?<body[^>]*>\\s*", options: [.CaseInsensitive, .DotMatchesLineSeparators])
			let closeTag = try! NSRegularExpression(pattern: "\\s*</\\s*body>.*$", options: [.CaseInsensitive, .DotMatchesLineSeparators])
			
			let sansOpen = openTag.stringByReplacingMatchesInString(html, options: [], range: NSRange(location: 0, length: html.characters.count), withTemplate: "")
			return closeTag.stringByReplacingMatchesInString(sansOpen, options: [], range: NSRange(location: 0, length: sansOpen.characters.count), withTemplate: "")
		} else if html.containsString("<html") {
			// Technically, <body> is optional.
			let openTag = try! NSRegularExpression(pattern: "^.*?<html[^>]*>\\s*", options: .CaseInsensitive)
			let closeTag = try! NSRegularExpression(pattern: "\\s*</\\s*html>.*$", options: .CaseInsensitive)
			
			let sansOpen = openTag.stringByReplacingMatchesInString(html, options: [], range: NSRange(location: 0, length: html.characters.count), withTemplate: "")
			return closeTag.stringByReplacingMatchesInString(sansOpen, options: [], range: NSRange(location: 0, length: sansOpen.characters.count), withTemplate: "")
		}
		return html
	}
}

let psh = PutStuffHere()
do {
	let templated = try psh.render("Tests/test.html", context: [
		"title": "This < that & such",
		"graf": "<i>Yeah!</i>"
	])
	print(templated)
} catch {
	print("Couldn't open file")
}