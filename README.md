## Description (this is still work in progress)

This is an application for yield farming dApp [VFat](https://vfat.io/) to send emails when the concentrated pool position goes out of range. The VFat does not have any notifications set up for emails, so I built my own to know when I need to rebalance. The VFat has rebalance capability, but I noticed that it does not work well all the time, so I like to be notified anyway.

## Running the code

1) Start new dev container.
2) Run code using 'ruby vfat_runner.rb' from the terminal in 'src' directory.
3) Check logs in 'out' folder.