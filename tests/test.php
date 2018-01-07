<!doctype html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<title>
		<?php
		    print("PHP Test");
		?>
    </title>
</head>
<body>
	<h3>Testing out some PHP here...</h3>
	<?php
		function printDecodedJson($header, $json)
		{
			print("<h5>$header</h5><textarea rows='10' cols='60'>");
			print(var_dump(json_decode($json)));
			print("</textarea>");
			print("<hr/>");
		}

		print("<p id='phpOut'>Printed out from php.</p>");

		printDecodedJson("URL Arguments", $argv[1]);
		printDecodedJson("Query String Arguments", $argv[2]);
		printDecodedJson("POST Data", $argv[3]);
		printDecodedJson("HTTP Request State", $argv[4]);
    ?>
</body>
</html>
