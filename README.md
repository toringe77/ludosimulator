# Ludo simulator
Simulates playing the game Ludo, so you don't have to.

## Background
Ludo is a very simple game. But compared to Snakes and Ladders, it actually gives the player choices. So which set of strategy will net you the most victories? This script, lets you code your own "ai"s, and pit them against each other.

## Features
The default setup, is 4 players with 4 tokens/pieces. But you can change that to as many as you like. The board will increase/decrease in size to fit the number of players.

Each turn will give the current player possible moves with outcomes. The script has set up player 2, 3 and 4 with specific strategies, and will choose based on the priorities from the possible moves. Player 1 (and 5+) is just moving a random piece/tower.

There are no graphics, but using the -verbose option, you can see the progress and "thinking" in text.

## Suggested features

Reading player profiles from a config file, or sending an object to the script with the different player behaviours.
Dedicated parameter to select the level of info, instead of using -Verbose.

## Files

- LudoSimulator.ps1 - The main script
- LudoSimulator.jpg - Visual representation of the board and the idea of cell numbers. File is based on this image: https://commons.wikimedia.org/wiki/File:Ludo-2.jpg
