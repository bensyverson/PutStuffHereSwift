// # Put Stuff Here
// Put Stuff Here is a minimalist, human-first templating system. Instead of writing something like `{{article.title}}` or `<%= titles[i] %>`, you just write `Put title here`.
// For example, given this context:

//```swift
//let context = [
//    "title": "Hello World!",
//    "body": "This is an example.",
//    "author": "Ben Syverson"
//]
//```
//
//…and this template…
//
//```html
//<h2> Put title here </h2>
//<p>
//Put body here
//</p>
//<p>
//– <em>  put author here  </em>
//</p>
//```
//
//…the result will be:
//
//```html
//<h2> Hello World! </h2>
//<p>
//This is an example.
//</p>
//<p>
//– <em>  Ben Syverson  </em>
//</p>
//```
//
//To edit a live example, visit [the main Put Stuff Here page](http://put.stuffhere.org/).
//
//## Background
//
//Much like Markdown, Put Stuff Here is based on an existing widespread practice. When normal people (non-programmers) create a template, they often type things like "Put Title Here." By taking that vernacular and building on it, Put Stuff Here reduces the burden on web developers, and empowers less technical folks to make changes.
//
//The result is more fluid collaboration, fewer bottlenecks and faster iterations. For example, a visual designer can create a template in [WebFlow](http://webflow.com/) or another WYSIWYG editor, which can be dropped directly into your prototype.
//
//## Features
//
//- Very few features!
//- Easy to understand.
//- Templates are fetched from `.html` files. There is no special file format, so you can open a template in your web browser to view it.
//- Templates are cached to a safe, efficient intermediate format.
//- All values are HTML-escaped by default. To insert HTML, use this parenthetical: `Put stuff (html) here`.
//
//## Dependencies
//
//Put Stuff Here has the absolute minimum number of dependencies to function. I import Foundation, and the [KituraTemplateEngine](https://github.com/IBM-Swift/Kitura-TemplateEngine), which is nothing but a protocol definition (with no dependencies of its own).

import Foundation
import KituraTemplateEngine

//## Parentheticals
//
//Put Stuff Here is in some ways the opposite of PHP—it *really* doesn't want to be a programming language. There are no loops, conditionals or built-in transformations in Put Stuff Here. I strongly believe that stuff belongs in your application logic, not your views. Once you mix logic into your template, you suddenly have many places to look for bugs, and the templates are much less readable to non-nerds.
//
//However, there are times when it's more readable to use a parenthetical than to export many different variables to the context. For example, `Put date (short) here` is preferable to `Put shortDate here`. As a minimalist system, Put Stuff Here defers to you. Use the ParentheticalDelegate protocol to render any custom parentheticals:

public protocol ParentheticalDelegate {
	func render(value: Any, parenthetical: String) -> String
}

//There is one exception; Put Stuff Here escapes a few HTML-oriented characters by default, so if your context contains `"title": "Me & You"`, the output of `put title here` will be `Me &amp; You`:
private func escapeHTML(html: String) -> String {
	return html.stringByReplacingOccurrencesOfString("___•••amp•••___", withString:"")
		.stringByReplacingOccurrencesOfString("&",  withString:"___•••amp•••___")
		.stringByReplacingOccurrencesOfString("<",  withString:"&lt;")
		.stringByReplacingOccurrencesOfString(">",  withString:"&gt;")
		.stringByReplacingOccurrencesOfString("'",  withString:"&apos;")
		.stringByReplacingOccurrencesOfString("\"", withString:"&quot;")
		.stringByReplacingOccurrencesOfString("___•••amp•••___", withString:"&amp;")
}

// But we need a way to insert raw HTML if necessary. That's why Put Stuff Here defines one built-in parenthetical to turn off HTML escaping: `(html)`.

enum Parentheticals : String {
	case HTML = "html"
}

// ## Stringification
// Speaking of escaping values, it pays to be careful when inserting an unknown entity (literally `Any` object) into your HTML. Put Stuff Here expects only strings or numbers, since it doesn't do loop over arrays or dictionaries. So if the value is a string, we return it. If it's a number, we stringify it. If it's something else, we print a warning, but don't throw an exception. This is a runtime error that can and should be glossed over. But we do add an HTML comment to aid in debugging.

private func stringify(thing: Any) -> String {
	switch thing {
	case let aString as String:
		return aString
	case let aNum as Float:
		return String(aNum)
	case let aNum as Double:
		return String(aNum)
	case let aNum as Int:
		return String(aNum)
	case let aNum as UInt:
		return String(aNum)
	case let aNum as Bool:
		return String(aNum)
	default:
		print("WARNING: Tried to templatize a non-String or non-Number value:\(thing)")
		return "<!--[skipped unknown type]-->"
	}
}

// ## Template Components
// Our templates are made up of TemplateStrings (for the HTML between variables: `<h1><span>`) and TemplateVariables (such as `put title here`, with an optional parenthetical):

private class TemplateComponent { }

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

// ## Template containers
// The template is, at its core, just an array of `TemplateComponents`. You could inherit from `SimpleTemplate` to create a plain-text or JSON templating system.

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
					// This is important; if there is no value to match the variable name in the context Dictionary, return an empty string.
					return ""
				}
				if let aParenthetical = aVar.parenthetical {
					if aParenthetical == Parentheticals.HTML.rawValue {
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

// ## Template parsing
// Now we just need to parse the input HTML into `TemplateComponents`. Here's our main regex. This can and should be extended with other syntaxes and languages. For now, getLocalRegex() always returns this:
private let regex = try! NSRegularExpression(pattern: "([\\s\\W]|^)(?:(?:put|insert)\\s+(.+?\\S)(?:\\s*\\(([^)]+)\\))?\\s+here)([\\W\\s]|$)", options: [.CaseInsensitive])

private func getLocalRegex() -> NSRegularExpression {
	return regex
}

// Finally, we can parse our HTML into TemplateStrings and TemplateVariables. `NSRegularExpression` is not the prettiest API to ever hit the scene:
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


// KituraTemplateEngine expects templating engines to throw errors if they run into major problems. For us, the worst that can happen is that we can't find the template file we've been pointed to.
enum PutErrorsHere : ErrorType {
	case FileReadError
}


// ## The main class
public class PutStuffHere : TemplateEngine {
	// Put Stuff Here is invoked as a singleton; you always communicate with `PutStuffHere.sharedInstance`
	public static let sharedInstance = PutStuffHere()
	private init(){}
	
	public var parentheticalDelegate : ParentheticalDelegate? = nil
	
	// We keep an internal cache of templates, so we're not parsing them every time.
	private var templates : [String : SimpleTemplate] = [:]
	
	// By default, PSH extracts whatever content is in the body. That way, multiple templates/views can be concatenated before getting wrapped in a master <html>. Set this to false if you want to include the entire HTML template.
	public var shouldExtractBody = true
	
	// This is a pretty terrible method, but it works for now.
	private func extractBody(html: String) -> String {
		if html.containsString("<body") {
			let openTag = try! NSRegularExpression(pattern: "^.*?<body[^>]*>\\s*", options: [.CaseInsensitive, .DotMatchesLineSeparators])
			let closeTag = try! NSRegularExpression(pattern: "\\s*</\\s*body>.*$", options: [.CaseInsensitive, .DotMatchesLineSeparators])
			
			let sansOpen = openTag.stringByReplacingMatchesInString(html, options: [], range: NSRange(location: 0, length: html.characters.count), withTemplate: "")
			return closeTag.stringByReplacingMatchesInString(sansOpen, options: [], range: NSRange(location: 0, length: sansOpen.characters.count), withTemplate: "")
		} else if html.containsString("<html") {
			// Technically, `<body>` is optional in an HTML file, so we have to handle the case where it's omitted.
			let openTag = try! NSRegularExpression(pattern: "^.*?<html[^>]*>\\s*", options: .CaseInsensitive)
			let closeTag = try! NSRegularExpression(pattern: "\\s*</\\s*html>.*$", options: .CaseInsensitive)
			
			let sansOpen = openTag.stringByReplacingMatchesInString(html, options: [], range: NSRange(location: 0, length: html.characters.count), withTemplate: "")
			return closeTag.stringByReplacingMatchesInString(sansOpen, options: [], range: NSRange(location: 0, length: sansOpen.characters.count), withTemplate: "")
		}
		return html
	}
	
	
	// KituraTemplateEngine wants us to identify what file extensions we handle…
	public var fileExtension : String { return "html" }
	// …and expose a public `render` function.
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
}