package;

import tink.unit.TestRunner;

class RunTests {

	static function main() {
		TestRunner.run([
			new TestStatic(),
		]).handle(function(o) travix.Logger.exit(o.errors));
	}
	
}