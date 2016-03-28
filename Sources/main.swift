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
			}.reduce("", combine:+)
	}
}

private func stringify(thing: Any) -> String {
	return ""
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

public class PutStuffHere : TemplateEngine {
	var parentheticalDelegate : ParentheticalDelegate? = nil
	private var templates : [String : SimpleTemplate] = [:]
	
	init(){
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
			templates[filePath] = HTMLTemplate(components: parseComponents(rawString))
		}
		
		guard let template = templates[filePath] else {
			throw PutErrorsHere.FileReadError
		}
		
		return template.render(context, delegate: parentheticalDelegate)
	}
	
	private func parseComponents(rawString: String) -> [TemplateComponent] {
		
		return []
	}
}

let psh = PutStuffHere()
do {
	let templated = try psh.render("Tests/test.html", context: ["title": "A title"])
	print(templated)
} catch {
	print("Couldn't open file")
}