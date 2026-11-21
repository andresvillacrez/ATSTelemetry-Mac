#!/bin/bash
# Variables de rendimiento de MoltenVK para ATS/ETS2.
# Steam debe reiniciarse una vez para que el juego las herede.

/bin/launchctl setenv MVK_CONFIG_LOG_LEVEL 0
/bin/launchctl setenv MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION 1
/bin/launchctl setenv MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS 0
/bin/launchctl setenv MVK_CONFIG_PREALLOCATE_DESCRIPTORS 1
/bin/launchctl setenv MVK_CONFIG_USE_COMMAND_POOLING 1
