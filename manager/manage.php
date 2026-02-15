<?php
// Disable output buffering for real-time streaming
if (ob_get_level()) ob_end_clean();
header('Content-Type: text/html; charset=utf-8');
ini_set('output_buffering', 'off');
ini_set('zlib.output_compression', false);
ini_set('implicit_flush', true);
ob_implicit_flush(true);
?>
<!DOCTYPE html>
<html>

<head>
    <title>WP Manager</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * {
            box-sizing: border-box;
        }

        body {
            font-family: sans-serif;
            padding: 20px;
            max-width: 800px;
            margin: 0 auto;
        }

        input,
        button {
            display: block;
            margin-top: 10px;
            width: 100%;
            height: 40px;
            border-radius: 4px;
            padding: 5px;
        }

        .section {
            border: 1px solid #ccc;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
        }

        h2 {
            margin-top: 0;
        }

        button {
            padding: 10px 20px;
            cursor: pointer;
        }

        .danger {
            background-color: #ffebee;
            border-color: #ffcdd2;
        }

        .danger button {
            background-color: #d32f2f;
            color: white;
            border: none;
        }

        input[type="datetime-local"] {
            padding: 8px;
        }

        #terminal {
            background-color: #000;
            color: #0f0;
            min-height: 100px;
            overflow-y: auto;
            padding: 20px;
            border-radius: 5px;
            /* break lines */
            white-space: pre-wrap;
        }
    </style>
</head>

<body>
    <div class="container">
        <h1>WordPress Docker Manager</h1>
        <pre id="terminal">WP System Datetime# <?php
                                                // Read time from WordPress container (which has libfaketime)
                                                $wpTime = trim(shell_exec('sudo docker exec wp-test-docker-wordpress-1 date "+%d %b, %Y %I:%M:%S%p" 2>/dev/null'));
                                                print($wpTime ?: date("d M, Y h:i:sA"));
                                                ?>
        <?php

        // Determine the script's base URL dynamically
        $baseUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (isset($_POST['action'])) {
                $action = $_POST['action'];

                if ($action === 'install_wp') {
                    // Run install_new.sh with real-time output
                    $siteTitle = $_POST['site_title'] ?? 'Test Site';
                    // Sanitize site title for shell command
                    $safeTitle = escapeshellarg($siteTitle);

                    flush();

                    $descriptorspec = array(
                        0 => array("pipe", "r"),
                        1 => array("pipe", "w"),
                        2 => array("pipe", "w")
                    );

                    $process = proc_open("bash /var/www/html/install_new.sh $safeTitle 2>&1", $descriptorspec, $pipes);

                    if (is_resource($process)) {
                        fclose($pipes[0]);

                        stream_set_blocking($pipes[1], false);

                        while (!feof($pipes[1])) {
                            $output = fgets($pipes[1]);
                            if ($output !== false) {
                                echo $output;
                                flush();
                            }
                            usleep(10000);
                        }

                        fclose($pipes[1]);
                        fclose($pipes[2]);
                        proc_close($process);
                    }

                    flush();
                } elseif ($action === 'change_time') {
                    // Change time and restart with real-time output
                    $newTime = $_POST['datetime'];

                    // Validate datetime format (basic check)
                    if (strtotime($newTime)) {
                        // Convert datetime-local format to a standard format
                        $formattedTime = date('Y-m-d H:i:s', strtotime($newTime));
                        $safeTime = escapeshellarg($formattedTime);

                        echo "<h3>Changing System Time...</h3>";
                        flush();

                        $descriptorspec = array(
                            0 => array("pipe", "r"),
                            1 => array("pipe", "w"),
                            2 => array("pipe", "w")
                        );

                        $process = proc_open("bash /var/www/html/change_time.sh $safeTime 2>&1", $descriptorspec, $pipes);

                        if (is_resource($process)) {
                            fclose($pipes[0]);

                            stream_set_blocking($pipes[1], false);

                            while (!feof($pipes[1])) {
                                $output = fgets($pipes[1]);
                                if ($output !== false) {
                                    echo nl2br(htmlspecialchars($output));
                                    flush();
                                }
                                usleep(10000);
                            }

                            fclose($pipes[1]);
                            fclose($pipes[2]);
                            proc_close($process);
                        }

                        echo "<br><strong>✓ Time change applied instantly. Refresh the page or check WordPress.</strong>";

                        flush();
                    } else {
                        echo "Invalid date format.";
                    }
                }
            }
        }
        ?>
    </pre>
        <div class="operation">


            <div class="section danger">
                <h2>Clean Install WordPress</h2>
                <p>Warning: This will delete the existing database and files!</p>
                <form method="post">
                    <input type="hidden" name="action" value="install_wp">
                    <label>
                        Site Title:
                        <input type="text" name="site_title" value="Test Site" required>
                    </label>
                    <br><br>
                    <button type="submit" onclick="return confirm('Are you sure? This will wipe everything.')">Install Fresh WP</button>
                </form>
            </div>

            <div class="section">
                <h2>System Time & Reboot</h2>
                <form method="post">
                    <input type="hidden" name="action" value="change_time">
                    <label>
                        Set System Date/Time:
                        <input type="datetime-local" name="datetime" required>
                    </label>
                    <br><br>
                    <button type="submit">Set Time & Reboot (5s)</button>
                </form>
            </div>
        </div>
    </div>
</body>

</html>