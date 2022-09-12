
# add an autoincrement key https://www.sqlite.org/autoinc.html
Function New-MySQLiteDBTable {
    [cmdletbinding(SupportsShouldProcess, DefaultParameterSetName = "filetyped")]
    [alias("New-DBTable", "ndbt")]
    [outputtype("None")]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = "Enter the path to the SQLite database file.", ValueFromPipelineByPropertyName, ParameterSetName = "filetyped")]
        [Parameter(ParameterSetName = "filenamed")]
        [Alias("fullname", "database")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(HelpMessage = "Specify an existing open database connection.", ParameterSetName = "cnxtyped")]
        [Parameter(ParameterSetName = "cnxnamed")]
        [ValidateNotNullOrEmpty()]
        [System.Data.SQLite.SQLiteConnection]$Connection,

        [Parameter(Mandatory, HelpMessage = "Enter the name of the new table. Table names are technically case-sensitive.")]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [parameter( HelpMessage = "Enter an ordered hashtable of column definitions", ParameterSetName = "filetyped")]
        [Parameter(ParameterSetName = "cnxtyped")]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Specialized.OrderedDictionary]$ColumnProperties,

        [parameter( HelpMessage = "Enter an array of column names.", ParameterSetName = "cnxnamed")]
        [Parameter(ParameterSetName = "filenamed")]
        [ValidateNotNullOrEmpty()]
        [string[]]$ColumnNames,

        [Parameter(HelpMessage = "Specify the column name to use as the primary key or index. Otherwise, the first detected property will be used.")]
        [string]$Primary,

        [Parameter(HelpMessage = "Overwrite an existing table. This could result in data loss.")]
        [switch]$Force,

        [Parameter(HelpMessage = "Keep an existing connection open.", ParameterSetName = "cnxtyped")]
        [Parameter(ParameterSetName = "cnxnamed")]
        [switch]$KeepAlive
    )

    Begin {
        Write-Verbose "[$((Get-Date).TimeOfDay)] $($myinvocation.mycommand)"
    } #begin
    Process {
        if ($Path) {

            $db = resolvedb -path $Path

            If ($db.exists) {
                $connection = opendb $db.path
            }
            else {
                Write-Warning "Cannot find the database file $($db.path)."
            }
            Write-Verbose "[$((Get-Date).TimeOfDay)] Using path $($db.Path)"
        }
        else {
            Write-Verbose "[$((Get-Date).TimeOfDay)] Using an existing connection"
        }
        if ($connection.state -eq 'Open' -OR $PSBoundparameters.ContainsKey("WhatIf")) {

            $cmd = $connection.CreateCommand()
            #test if table already exists
            if (-not $Force) {
                $cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name='$Tablename' COLLATE NOCASE;"
                Write-Verbose "[$((Get-Date).TimeOfDay)] Using table $Tablename"
                Write-Verbose "[$((Get-Date).TimeOfDay)] $($cmd.CommandText)"

                $ds = New-Object System.Data.DataSet
                $da = New-Object System.Data.SQLite.SQLiteDataAdapter($cmd)
                [void]$da.fill($ds)

                if ($ds.Tables.rows.name -contains $Tablename) {
                    Write-Warning "The table $Tablename already exists. Use -Force to overwrite it."
                    $tableFree = $False
                }
                else {
                    $TableFree = $True
                }
            } #if -not -Force
            else {
                #drop the table
                $query = "DROP TABLE IF EXISTS $Tablename;"
                $cmd.CommandText = $query
                if ($pscmdlet.ShouldProcess($query)) {
                    [void]$cmd.ExecuteNonQuery()
                }
                $tablefree = $True
            }

            If ($TableFree ) {
                Write-Verbose "[$((Get-Date).TimeOfDay)] Creating table $Tablename"
                [string]$query = "CREATE TABLE $tablename "

                if ($pscmdlet.ParameterSetName -match 'typed') {
                    $keys = $ColumnProperties.Keys
                    #9/9/2022 Need to let the user specify the primary key
                    #property. Issue #13 JDH
                    if (-Not ($PSBoundparameters.ContainsKey("Primary"))) {
                        $primary = $keys | Select-Object -First 1`
                        $cols = $keys | Select-Object -Skip 1

                    } else {
                        Write-Verbose "[$((Get-Date).TimeOfDay)] Removing $primary from column set"
                        $cols = $keys | Where-Object {$_ -ne $primary}
                    }

                    $primaryType = $ColumnProperties.item($Primary)

                    Write-Verbose "[$((Get-Date).TimeOfDay)] Primary key = $primary $PrimaryType"
                    $query += "($Primary $PrimaryType PRIMARY KEY"
                    foreach ($col in $cols) {
                        $colType = $ColumnProperties.item($col)
                        Write-Verbose "[$((Get-Date).TimeOfDay)] $col $($coltype)"
                        $query += ",$col $coltype"
                    }
                    $query += ");"
                }
                else {
                    $keys = $ColumnNames -join ","
                    $query += "($($keys))"
                }

                $cmd = $connection.CreateCommand()
                $cmd.CommandText = $query
                Write-Verbose "[$((Get-Date).TimeOfDay)] $query"
                if ($pscmdlet.ShouldProcess($query)) {
                    [void]$cmd.ExecuteNonQuery()
                }
            }
        }
        else {
            Write-Verbose "[$((Get-Date).TimeOfDay)] There is no open database connection"
        }
    } #process
    End {
        if ($connection.state -eq 'Open' -AND (-Not $KeepAlive)) {
            Write-Verbose "[$((Get-Date).TimeOfDay)] Closing database connection"
            closedb -connection $connection -cmd $cmd
        }
        Write-Verbose "[$((Get-Date).TimeOfDay)] Ending $($myinvocation.mycommand)"
    } #end
}
