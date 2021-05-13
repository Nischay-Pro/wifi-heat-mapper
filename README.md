# whm

## whm aka wifi-heat-mapper

whm also known as `wifi-heat-mapper` is a Python library for benchmarking Wi-Fi networks and gather useful metrics which can be converted into meaningful easy to understand heatmaps. The aim of the tool is to assist network engineers, admins and homelabbers in figuring out the performance of their Access Points and Routers.

This tool is heavily inspired by [python-wifi-survey-heatmap](https://github.com/jantman/python-wifi-survey-heatmap) by [Jason Antman](www.jasonantman.com).

## Supported Platform
* Operating System
    - Linux x86_64 (64 bit)

## Dependencies
### Required
* Python version: 3.7 - 3.9
* iperf3 >= 0.1.11
* matplotlib >= 3.4.0
* tqdm >= 4.55.0
* Pillow >= 8.2.0
* scipy >= 1.6.0
* numpy >= 1.20.0
* PySimpleGUI >= 4.34.0

### Optional
* [Ookla Speedtest CLI](https://www.speedtest.net/apps/cli) >= 1.0.0.2

## Installation

The easiest way to install whm is via [pip](https://pip.pypa.io/en/stable/).

```bash
$ pip install whm
```

Alternatively, you can clone the repository and compile it.

```bash
$ git clone https://github.com/Nischay-Pro/wifi-heat-mapper.git
$ cd wifi-heat-mapper
$ python3 setup.py install
```

## Usage

### Server Configuration

whm requires connecting to an `iperf3` instance running in server mode. On a machine which is available in your LAN run `iperf3 -s` to start iperf3 in server mode in foreground. I strongly recommend running the iperf3 instance on a wired computer or virtual machine instance.

By default iperf3 will use TCP and UDP ports 5201.


### Client Configuration

#### Configuration Bootstrapping

Initially, you need to bootstrap your configuration specifying the graphs you would like to view, the wireless interface you will be using to profile and the SSID configured.

whm supports multiple graphs allowing users to select one, more or all graphs. The tool will automatically gather the appropriate metrics to generate the graphs.

```bash
$ whm bootstrap
```

> **NOTE:** To profile metrics from Ookla speedtest, user needs to ensure that they have installed the binary provided by Ookla and is accessible from `$PATH` environment variable.

After completing the process a file called `config.json` will be available in the directory you have executed the command from.

To specify a save path and file name use the `--config` option including the path and the filename for storing the configuration details.

For example:

```bash
$ whm bootstrap --config /home/example/whm/test.json
```

#### Benchmarking

Once you have generated the configuration file you can start benchmarking.

```bash
$ whm benchmark -m examples/sample_floor_map.jpg -s 192.168.1.100 -c config.json 
```

Command-line options used:

* `-m` or `--map` is the path to the floop map.
* `-s` or `--server` is the IP address(:port) of the iperf3 server. You can specify a port using `IPADDRESS:PORT`, like `192.168.1.100:5123`. If no port is specified the default port `5201` is used.
* `-c` or `--config` is the path to the configuration file you bootstrapped earlier.

After specifying the appropriate options a GUI window will open up.

You will be presented with a canvas with your floor map loaded.

![GUI-1](images/gui-1.png)

* Exit: To quit benchmarking
* Save Results: Save the results you have captured till now. Results are stored in the same configuration file you have used earlier.
* Plot: To plot the results you have captured.
* Clean All: Wipes the canvas clean removing all captured metrics.

#### Gathering metrics

1. Start by Left-clicking on the canvas roughly at a position where you are capturing the metrics from. A gray circle with blue outline should appear now.

![GUI-2](images/gui-2.png)

2. Now right-click on the circle. You will be presented with a drop-down menu having 3 options
    * Benchmark: whm will start capturing metrics at this position.
    * Delete: whm will delete the point and metrics (if any) at this point.
    * Mark / Un-Mark as Station: whm will mark this point as a Base station. Useful if you want to have a heatmap displaying the position of one or more base stations. You would still need to benchmark at this point. The border color will change from black to red indicating a base station point.

![GUI-3](images/gui-3.png)

3. Select `Benchmark` and wait for a few seconds (10 seconds to 2 minutes) depending on the graphs you have requested. Once benchmarking is done the circle's fill color changes from gray to light blue.

![GUI-4](images/gui-4.png)

4. Now move to the new position you want to benchmark from and select the rough position in the canvas.
5. whm requires atleast 4 points to generate plots. I strongly recommend profiling as many points as possible to increase the accuracy of the heatmap.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to run tests as appropriate

## License
[GPLv3](https://choosealicense.com/licenses/gpl-3.0/)