//You can authenticate once, and then use your cookies. Unfortunatelly it requires an additional action from you:

//Run "Dev Tools" tools and navigate "Network" tab (If you are in Chrome "Dev tools" make sure you have "Preserve log" option checked)
//Log in to Google
//Filter requests for "/signin/sl/challenge" pattern
//In "Response" section search for "set-cookie: " entries. You will need 3 values: SID (71 characters), HSID, SSID (both 17 characters). Then you can use it to generate cookies, just run the function with your variables:




const fs = require('fs')
const alerts = require('google-alerts-api')
 




const SID = ''
const HSID = ''
const SSID = ''

fs.writeFileSync('./cookies.data', alerts.generateCookiesBySID(SID, HSID, SSID))
