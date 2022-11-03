<#
    .SYNOPSIS
    Simulates playing the game Ludo

    .DESCRIPTION
    This will run several games in a row and summarize which player won the most.
    Each player can be set up to prioritize types of moves.

    .PARAMETER NumPlayer
    Specifies number of players (Default: 4, Min: 1)

    .PARAMETER NumTokens
    Specifies numbers of tokens/pieces per player (Default: 4, Min: 1)

    .PARAMETER NumRounds
    Specifies number of rounds that should be played (Default: 20, Min: 1)

    .INPUTS
    None. You cannot pipe objects to LudoSimulator.

    .OUTPUTS
    Custom object sorted by number of wins per player.

    .EXAMPLE
    PS> .\LudoSimulator.ps1
    
    Count Name
    ----- ----
        8 4
        7 2
        3 3
        2 1

    .EXAMPLE
    PS> .\LudoSimulator.ps1 -NumRounds 5

    Count Name
    ----- ----
        2 2
        1 1
        1 3
        1 4

    .EXAMPLE
    PS>  .\LudoSimulator.ps1 -NumPlayers 6 -NumRounds 1

    Count Name
    ----- ----
        1 4   

    .LINK
    Most Recent Version: https://github.com/toringe77/ludosimulator

    .Link
    WikiPedia: https://en.wikipedia.org/wiki/Ludo

    .Link
    BoardGameGeek: https://boardgamegeek.com/boardgame/2136/pachisi
#>

[CmdletBinding()]
param (
    [ValidateRange(1, [int]::MaxValue)]
    [int]$NumPlayers = 4,
    [ValidateRange(1, [int]::MaxValue)]
    [int]$NumTokens = 4,
    [ValidateRange(1, [int]::MaxValue)]
    [int]$NumRounds = 20
)

Function Get-DiceRandom
{
    Get-Random -Minimum 1 -Maximum 7
}

Function New-Token
{
    Param (
        [int]$Number,
        [int]$Owner,
        [int]$UniqueNumber,
        [int]$StartCell
    )
    New-Object -TypeName psobject -property @{
        Number = $Number
        CurrentCell = 0
        Distance = 0
        Owner = $Owner
        StartCell = $StartCell
        ID = $UniqueNumber
    }
}

Function New-Player
{
    Param (
        [int]$Number,
        [int]$StartCell
    )
    New-Object -TypeName PSObject -Property @{
        Number = $Number
        StartCell = $StartCell # not used
        CompletedTokens = 0 # not used
    }
}

Function Move-Token
{
    Param (
        [PSCustomObject]$MoveToken,
        [PSCustomObject]$AllTokens,
        [int]$DiceThrow,
        [int]$MaxCells,
        [switch]$JustCheck = $false
    )

    $maxDistance = $MaxCells + 5
        
    $resultObject = [PSCustomObject]@{
        TokenID = $MoveToken.ID
        OutOfPocket = $false
        NumTokensStack = 0
        NumTokensRemoved = 0
        TokensRemovedOwner = 0
        JustChecked = $JustCheck
        IsOutOfGame = $false
        WillFinish = $false
        WillEnterSafeZone = $false
        ValidMoves = $true
        PathBlocked = $false
        NewDistance = 0
    }
    $newDistance = 0
    $newCell = 0
    Write-Debug "First Calculating new Distance and cell, and what is on that cell."
    if ($MoveToken.Distance -eq $maxDistance )
    {
        Write-Debug "Token is out of the game"
        $resultObject.ValidMoves = $false
        $resultObject.IsOutOfGame = $true
    }
    elseif ( $MoveToken.currentcell -eq 0 -and $DiceThrow -eq 6 )
    {
        Write-Debug "Token will go on to the table"
        $newDistance = 1
        $newCell = $MoveToken.StartCell
    }
    elseif ( $MoveToken.currentcell -eq 0 -and $DiceThrow -ne 6 )
    {
        Write-Debug "Token cannot start."
        $resultObject.ValidMoves = $false
    }
    else
    {
        Write-Debug "Assuming regular move"
        $newDistance = $MoveToken.Distance + $DiceThrow
        if ( $newDistance -gt $maxDistance )
        {
            $resultObject.ValidMoves = $false
        }
        elseif ($MoveToken.CurrentCell -eq -1 -and $newDistance -lt $maxDistance)
        {
            $resultObject.ValidMoves = $false
        }
        elseif ( $newDistance -ge $MaxCells )
        {
            $newCell = -1 # We are out of danger! (We might already be, but who cares.)
        }
        else
        {
            Write-Debug "We are still in the rat race"
            $newCell = $MoveToken.CurrentCell + $DiceThrow
            if ( $newCell -gt $MaxCells )
            {
                # Board is a circle. When we go past the highest numbered cell, we start on cell #1 again
                $newCell -= $MaxCells 
            }
        }
    }

    if ( ($MoveToken.currentCell -ne -1 ) -and ($newDistance -gt 1) -and ($MoveToken.CurrentCell -lt $MaxCells) -and ($MoveToken.CurrentCell -ne ($MaxCells -1 )) )
    {
        Write-Debug "We move on the track. We are not on the last cell before safezone. Need to see if there are some towers blocking our paths."
        $startPath = $MoveToken.CurrentCell + 1
        $DistanceToSafeZone = $MaxCells - $MoveToken.Distance - 1
        if ( $DistanceToSafeZone -le $DiceThrow )
        {
            Write-Debug "The distance to safety is less or equal to the dicethrow. Using that instead."
            $endPath = $moveToken.CurrentCell + $DistanceToSafeZone
        }
        else
        {
            Write-Debug "Still a bit to go. Using only the dice throw as base for path."
            $endPath = $MoveToken.CurrentCell + $DiceThrow -1
        }
             
        foreach ( $passingCell in $startPath..$endPath)
        {
            $tokensInPassingCell = $AllTokens | where-object { $_.currentCell -eq $passingCell } 
            $numPassingTokens = $tokensInPassingCell | Measure-Object | Select-Object -ExpandProperty Count
            $ownerPassingTokens = $tokensInPassingCell | Select-Object -First 1 | Select-Object -ExpandProperty Owner

            if ( $numPassingTokens -ge 2 -and $ownerPassingTokens -ne $MoveToken.owner )
            {
                Write-Verbose "Path is blocked by enemy tower."
                $resultObject.PathBlocked = $true
                $resultObject.ValidMoves = $false
            }
        }
    }


    if ( $newCell -gt 0 )
    {
        Write-Debug "We are on the board. We need to check if we land on something."
        $landOnTokens = $AllTokens | Where-Object { $_.currentCell -eq $newCell -and ($_.currentcell -ne -1) }
        if ( $landOnTokens )
        {
            $numTokensInTargetCell = ($landOnTokens | Measure-Object ).Count
            $targetCellOwner = ( $landOnTokens | Select-Object -first 1 ).Owner
            $homeCell = (( $landOnTokens | Select-Object -first 1 ).Distance -eq 1) # Homecell is the first cell. No spawn-ganking!
            Write-Debug "We land on something, but what?"
            if (  $targetCellOwner -eq $MoveToken.Owner )
            {
                Write-Debug "It is ours! We can make a stack."
                $resultObject.NumTokensStack = $numTokensInTargetCell + 1 # We can move a stack, but this needs to be handled outside this function.
            }
            else
            {
                Write-Debug "It is not ours. We need to see if it is their home."
                if ( $homeCell )
                {
                    Write-Debug "Damn, cannot land here."
                    $resultObject.PathBlocked = $true
                    $resultObject.ValidMoves = $false
                }
                else
                {
                    Write-Debug "Sweet. We can send them home!"
                    $resultObject.NumTokensRemoved = $numTokensInTargetCell
                    $resultObject.TokensRemovedOwner = $targetCellOwner 
                }
            }
        }
    }

    Write-Debug "Analyzing the situation."

    if ( $resultObject.ValidMoves -eq $false )
    {
        # Skipping the rest of the checks, as it has no valid moves
        Write-Debug "No valid moves!"
    }
    elseif ( $MoveToken.Distance -eq $maxDistance )
    {
        Write-Debug "Token is already finished. No need to do anything."
        $resultObject.IsOutOfGame = $true
        $resultObject.ValidMoves = $false
            
    }
    elseif ( $newDistance -eq 1 )
    {
        Write-Debug "Token can be put on the board from the pocket."
        $resultObject.OutOfPocket = $true
        $resultObject.NewDistance = $newDistance
    }
    elseif ( $newDistance -eq $maxDistance )
    {
        Write-Debug "Token will finish."
        $resultObject.WillFinish = $true
        $resultObject.NewDistance = $newDistance
    }
    elseif ( $newCell -eq -1 -and  ($MoveToken.CurrentCell -ne -1 ))
    {
        Write-Debug "Token is not in, but will enter the safezone"
        # Maxcells is also start of the finishtrack. 
        $resultObject.WillEnterSafeZone = $true
        $resultObject.NewDistance = $newDistance
    }
    elseif ( $MoveToken.CurrentCell -ne -1 )
    {
        Write-Debug "We are not on hometrack. othing special will happen. Just move."
        $resultObject.NewDistance = $newDistance
    }

    if ( -not $JustCheck -and $resultObject.ValidMoves -eq $true)
    {
        Write-Debug "Activate predictions. "
        Write-Debug "Moving Token"
        $MoveToken.CurrentCell = $newCell
        $MoveToken.Distance = $newDistance
        Write-Debug "Removing Token(s)."
        if ( $resultObject.NumTokensRemoved -gt 0 )
        {
            $tokensToBeRemoved = $AllTokens | Where-Object { ($_.CurrentCell -eq $MoveToken.CurrentCell) -and ($_.owner -ne $movetoken.Owner)}
            foreach ( $tokenToBeRemoved in $tokensToBeRemoved )
            {
                $tokenToBeRemoved.CurrentCell = 0
                $tokenToBeRemoved.Distance = 0
            }
        }
    }
    # Return Status
    $resultObject
}

$totalWinners = @()
$round = 0
while ( $round -lt $NumRounds )
{
    $round ++
    Write-Verbose "Round: $round"
    Write-verbose "Setting up the board."
    $players = @()
    $tokens = @()
    $currentToken = 0
    $startCell = 1

    foreach ( $initPlayer in 1..$NumPlayers )
    {
        Write-Verbose "Setting up player $initPlayer"
        $players += New-Player -number $initPlayer -Startcell $startCell
        foreach ( $initToken in 1..$NumTokens  )
        {
            $currentToken++
             Write-Verbose "Setting up token $currentToken, $initToken for this player"
            $tokens += New-Token -Number $initToken -Owner $initPlayer -UniqueNumber $currentToken -StartCell $startCell
        }
        $startCell += 13
    }
    #$players | ft
    #$tokens | ft

    Write-verbose "Setting up board."
    $maxCells = 13 * $NumPlayers # Assuming we have a board that fits all players.
    $maxDistance = $MaxCells + 5 # The distance each token have to travel, is the entire board plus 5.
    Write-Verbose "MaxCells: $maxCells MaxDistance: $maxDistance"
    $winners = @()
    $turn = 0
    $longestStreak = 0
    # We will play until we have a winner. (No quitting!)
    while ( ($winners | measure-object ).count -eq 0)
    {
        $turn++
        Write-Verbose "Turn: $turn"
        # In a 4 player game:
        # Distance 1 and 52 to 57 is safe
        # Red Start 1, End 51.
        # Green Start 14, End 12 (Red + 13)
        # Yellow Start 27 End 25. (Green + 13)
        # Blue Start 40 End 38 (Yellow + 13)

        foreach ( $player in $players )
        {
            $streak = 0
            do
            {
                $diceThrow = Get-DiceRandom #throwing the dice
                $reThrow = $false # Flag if you can throw again.
                $moveTokenID = $null
                $moveToken = $null
                $moveTokens = @()
                $moveTower = $true # We assume the stack will be moved. Unless people have different tactics.
                $streak++ # How many times have we thrown the dice in our turn
                Write-Verbose "Player: $($player.Number). Dice: $diceThrow. Streak: $streak"
                if ($streak -gt $longestStreak ) { $longestStreak = $streak } # For statistics
                $playerTokens = $tokens | Where-Object { $_.Owner -eq $player.Number } # Selecting current player tokens
                #$playertokens | ft

                Write-Debug "Analyzing possible moves"
                $tokenAnalyze = @()
                foreach ( $playerToken in $playerTokens )
                {
                    $tokenAnalyze += Move-Token -JustCheck -MoveToken $playerToken -AllTokens $tokens -DiceThrow $diceThrow -MaxCells $maxCells
                }
                $numTokensInPocket = $playerTokens | Where-Object { $_.Distance -eq 0 } | Measure-Object | Select-Object -ExpandProperty count
                #$tokenAnalyze | ft *
                Write-Debug "Checking if a valid move is present, and if we have tokens on the track."
                $validMoves =  $tokenAnalyze | Where-Object { $_.ValidMoves -eq $true }
                $numValidMoves =  $validMoves | Measure-Object | Select-Object -ExpandProperty Count
                $numOutOfPocket = $tokenAnalyze | Where-Object { $_.OutOfPocket -eq $true } | Measure-Object | Select-Object -ExpandProperty Count

                if ( $numValidMoves -eq 0 )
                {   # If you have no pieces on the board, you can throw up to 3 times to get one on the board.
                     if ($streak -lt 3  -and $numTokensInPocket -eq $NumTokens) {  $reThrow = $true } else {  $reThrow = $false} 
                }
                else
                {
                    # Selecting Player Behaviour
                    # Todo: Being able to select priorities for each player from command line.
                    if ( $player.Number -eq 2 ) 
                    {
                        # 1st priority: Hunting pieces
                        $moveTokenID = $null
                        if ( $validMoves | Where-Object { $_.NumTokensRemoved -gt 0 }   )
                        {
                            Write-Verbose "Removing tokens. Taking out the highest stack."
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.NumTokensRemoved -gt 0 } | Sort-object -Descending NumTokensRemoved | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $numOutOfPocket -gt 0 )
                        {
                            Write-Verbose "Getting out of Pocket"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.OutOfPocket -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.WillFinish -eq $true }   )
                        {
                            Write-Verbose "Finishing move!"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.WillFinish -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.NumTokensStack -gt 0 }   )
                        {
                            Write-Verbose "Stacking tokens"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.NumTokensStack -gt 0 } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.WillEnterSafeZone -eq $true }   )
                        {
                            Write-Verbose "Going to safezone"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.WillEnterSafeZone  -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        else
                        {
                            Write-Verbose "No preffered moves found. Choosing Random piece."
                            $randomChoice = Get-Random -Minimum 0 -Maximum $numValidMoves
                            $moveTokenID = $validMoves | Select-Object -Index $randomChoice | Select-Object -ExpandProperty TokenID
                        }
                        $moveTower = $true
                    }
                    elseif ( $player.Number -eq 3  )
                    {
                        # 1st priority: getting tokens out of pocket. Playing semi defensively.
                        $moveTokenID = $null
                        if ( $numOutOfPocket -gt 0 )
                        {
                            Write-Verbose "Getting out of Pocket"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.OutOfPocket -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.WillFinish -eq $true }   )
                        {
                            Write-Verbose "Finishing move!"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.WillFinish -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.WillEnterSafeZone -eq $true }   )
                        {
                            Write-Verbose "Going to safezone"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.WillEnterSafeZone  -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.NumTokensRemoved -gt 0 }   )
                        {
                            Write-Verbose "Removing tokens"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.NumTokensRemoved -gt 0 } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.NumTokensStack -gt 0 }   )
                        {
                            Write-Verbose "Stacking tokens"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.NumTokensStack -gt 0 } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        else
                        {
                            Write-Verbose "No preffered moves found. Choosing Random piece."
                            $randomChoice = Get-Random -Minimum 0 -Maximum $numValidMoves
                            $moveTokenID = $validMoves | Select-Object -Index $randomChoice | Select-Object -ExpandProperty TokenID
                        }
                        $moveTower = $true
                    
                    }
                    elseif ( $player.Number -eq 4  )
                    {
                        # 1st priority: getting tokens out of pocket. Playing semi aggressively
                        $moveTokenID = $null
                        if ( $numOutOfPocket -gt 0 )
                        {
                            Write-Verbose "Getting out of Pocket"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.OutOfPocket -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }


                        elseif ( $validMoves | Where-Object { $_.WillFinish -eq $true }   )
                        {
                            Write-Verbose "Finishing move!"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.WillFinish -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.NumTokensRemoved -gt 0 }   )
                        {
                            Write-Verbose "Removing tokens"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.NumTokensRemoved -gt 0 } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.NumTokensStack -gt 0 }   )
                        {
                            Write-Verbose "Stacking tokens"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.NumTokensStack -gt 0 } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }
                        elseif ( $validMoves | Where-Object { $_.WillEnterSafeZone -eq $true }   )
                        {
                            Write-Verbose "Going to safezone"
                            $moveTokenID = $tokenAnalyze | Where-Object { $_.WillEnterSafeZone  -eq $true } | Select-Object -First 1 | Select-Object -ExpandProperty TokenID
                        }


                        else
                        {
                            Write-Verbose "No preffered moves found. Choosing Random piece."
                            $randomChoice = Get-Random -Minimum 0 -Maximum $numValidMoves
                            $moveTokenID = $validMoves | Select-Object -Index $randomChoice | Select-Object -ExpandProperty TokenID
                        }
                        $moveTower = $true
                    
                    }
                    else
                    {
                        # Default Playerbehavour. Moving random pieces with valid move.
                        Write-Verbose "Choosing Random piece. Moving tower if possible"
                        $randomChoice = Get-Random -Minimum 0 -Maximum $numValidMoves
                        $moveTokenID = $validMoves | Select-Object -Index $randomChoice | Select-Object -ExpandProperty TokenID
                        $moveTower = $true
                    }
                    Write-Debug "Executing move"
                    $moveToken = $playerTokens | Where-Object { $_.ID -eq $moveTokenID }
                    if ( -not $moveTower -or $moveToken.Distance -eq 0 )
                    {
                        Write-Debug "Move a single piece."
                        $moveTokens = $moveToken
                    }
                    else
                    {
                        Write-Debug "Move the tower if any"
                        $moveTokens = $playerTokens | Where-Object { $_.Distance -eq ( $movetoken.Distance ) }
                    }
                    foreach ( $move in $moveTokens )
                    {
                        #$move | ft
                        Move-Token -MoveToken $move -AllTokens $tokens -DiceThrow $diceThrow -MaxCells $maxCells | Out-Null
                        #| ft *
                    }
                    Write-Debug "Checking if we have a winner."
                    $player.CompletedTokens = ($playerTokens | Where-Object { $_.Distance -eq $maxDistance } | Measure-Object ).count
                    if (  $player.CompletedTokens -eq $NumTokens )
                    {
                        $didWin = $true # No Rethrow even on 6.
                        $winners += $player
                        Write-Verbose "Player $player wins round $round"
                    }
                    else
                    {
                        $didWin = $false
                    }
                }
            }
            while ( ($diceThrow -eq 6 -or $reThrow) -and -not $didWin )
        }
    }
    #$players | ft
    Write-Verbose "Winner: Player(s): $($winners.number). Turn: $turn. Longest streak: $longestStreak"
    $totalWinners += $winners
}
Write-Verbose "Winners: $($totalWinners.number)."
$totalWinners | Group-Object number | Sort-Object -Descending Count | Select-Object Count,Name
