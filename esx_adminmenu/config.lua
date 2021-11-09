Config = {}

-- Menu
Config.AllowedGroups = {"user","mod","admin","superadmin"} 

Config.MenuKey = 56 -- https://docs.fivem.net/docs/game-references/controls/
Config.MenuPosition = "left" -- right/left

Config.OpenMenu                 = "mod"
Config.GiveCarToGarage          = "superadmin"
Config.SpawnDonateCars          = "superadmin"
Config.RepairVehicle            = "mod"
Config.DeleteVehicle            = "mod"
Config.SetMeDriver              = "mod"
Config.GiveBlackMoney           = "superadmin"
Config.SendToJail               = "admin"
Config.SetPassenger             = "mod"
Config.Ban                      = "admin"
Config.UnBan                    = "admin"
Config.GetRentedHomes           = "admin"
Config.GetHomeItems             = "admin"
Config.GetPlayerBillings        = "admin"
Config.ManageGarageVehicles     = "admin"
Config.SendToCommunityService   = "mod"
Config.vMenu                    = "superadmin"
Config.Priority					= "superadmin"

Config.PriorityHook = 'https://discord.com/api/webhooks/847116991248203877/C72oqVe2r-lDY8TCa9O-h6f3ErQ9EUs194EXWXJ1i3V4QC_XO5nUzjNRCCRs15qfK4Np'
Config.vMenuHook = 'https://discord.com/api/webhooks/847117084155445298/0haB3MZQtH5MKNn8fJvPZdp7w_qETBmun1eTLgmFeSVbgAOLUvhjm1ngMd1W6Dwqw5Tp'
Config.BanWebhook = ''

Config.DonatorVehicleTableInDatabase = 'blacks'
Config.DonatorVehiclesCategoryNamesInDatabase = 'Donate Cars'

Config.PlateLetters  = 3
Config.PlateNumbers  = 3
Config.PlateUseSpace = true

-- Permissions
Config.CannotBeBanned = {
	'steam:1100001357250b0', --spyros
}

Config.CheckDiscord = true
Config.CheckDiscordMessage = 'Please link your account.'
Config.DiscordAllowed = {
    'steam:1100001357250b0', --spyros
}

-- Priority
Config.SteamPriority = {
    ["steam:1100001357250b0"] = 100, --spyros
}

Config.PriorityIps = {}

Config.PriorityOnlyOnStartup = false
Config.PriorityOnlyOnStartupTime = 2

Config.PriorityJobs = {
	{job='police', power=65},
	{job='ambulance', power=65}
}

-- require people to run steam
Config.RequireSteam = false

-- "whitelist" only server
Config.PriorityOnly = false

-- disables hardcap, should keep this true
Config.DisableHardCap = true

-- will remove players from connecting if they don't load within: __ seconds; May need to increase this if you have a lot of downloads.
-- i have yet to find an easy way to determine whether they are still connecting and downloading content or are hanging in the loadscreen.
-- This may cause session provider errors if it is too low because the removed player may still be connecting, and will let the next person through...
-- even if the server is full. 10 minutes should be enough
Config.ConnectTimeOut = 600

-- will remove players from queue if the server doesn't recieve a message from them within: __ seconds
Config.QueueTimeOut = 90

-- will give players temporary priority when they disconnect and when they start loading in
Config.EnableGrace = true

-- how much priority power grace time will give
Config.GracePower = 5

-- how long grace time lasts in seconds
Config.GraceTime = 360

-- on resource start, players can join the queue but will not let them join for __ milliseconds
-- this will let the queue settle and lets other resources finish initializing
Config.JoinDelay = 0

-- will show how many people have temporary priority in the connection message
Config.ShowTemp = true

-- simple localization
Config.Language = {
    joining = "\xF0\x9F\x8E\x89Joining",
    connecting = "\xE2\x8F\xB3Connecting",
    idrr = "\xE2\x9D\x97[Queue] Error: Couldn't retrieve any of your id's, try restarting.",
    err = "\xE2\x9D\x97[Queue] There was an error",
    pos = "\xF0\x9F\x90\x8CYou are %d/%d in queue \xF0\x9F\x95\x9C%s",
    connectingerr = "\xE2\x9D\x97[Queue] Error: Error adding you to connecting list",
    timedout = "\xE2\x9D\x97[Queue] Error: Timed out?",
    wlonly = "\xE2\x9D\x97[Queue] You must be whitelisted to join this server",
    steam = "\xE2\x9D\x97 [Queue] Error: Steam must be running"
}