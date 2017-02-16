## SpyKING CIRCUS processor plugin to MountainLab

This project wraps the spike sorting algorithm from [SpyKING CURCUS](http://www.yger.net/software/spyking-circus/) as a processor plugin of [MountainLab](https://github.com/magland/mountainlab).

This plugin is at a very early stage and is under prelim development. More info coming soon.

## Instructions

First, install MountainLab. Then clone this repository into the packages directory:

```bash
cd mountainlab/packages
git clone https://github.com/magland/ml_spyking_circus.git
```
Next you need to install spyking circus using anaconda. More info coming soon


If the processing daemon is running, restart it:

```bash
mp-daemon-restart
```

Now you should have a new processor registered in mountainprocess. Try:

```bash
mp-spec ml_spyking_circus
```

To run a prelim comparison with mountainsort on synthetic data follow the instructions in ml_spyking_circus/test_compare.


