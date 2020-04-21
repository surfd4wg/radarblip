///Coded by sidthetech@gmail.com using the google-alert-api npm node.
//Thanks to the author..

//This code takes in a keyword,
//attempts to create a google alert based on that keyword via the account credentials provided below:
//see https://www.npmjs.com/package/google-alerts-api#generate-cookies   how to generate a cookie, which I needed
//in order to get his working.  It's not very clear, but read carefully.
//do the instructions to capture the log feed, then when have this listen COMMAND+R to the feed if not already.
//this needs to record it, and then you can filter per instructions.  Find the entrty line popup on the bottom dialog box,
// then click that and you'll see some tabs pertaining to the instructions. ie cookies and stuff...

//This node will take a parameter keyword and attempt to make a rss feed,
//if the feed keyword exists, it will attempt to locate the feed and pass the RSS.
//The RSS feed is the ONLY thing that should come out of this function for simplicity.
//Else report an error.



//This is your keyword!
const kw = process.argv[2];

const fs = require('fs')
const alerts = require('google-alerts-api')
const { HOW_OFTEN, DELIVER_TO, HOW_MANY, SOURCE_TYPE } = alerts;
 
let alert_id = '';
let alert_rss = '';


alerts.configure({
    cookies: fs.readFileSync('./cookies.data').toString(),
    password: 'password',
    mail: 'your@email.com'
});
 

alerts.sync(() => {
    const alertToCreate = {
    	howOften: HOW_OFTEN.AS_IT_HAPPENS,
        sources: SOURCE_TYPE.AUTOMATIC, // default one
        lang: 'en',
        name: kw,
        region: '', // or do not specify it at all, if you want "All Regions"
        howMany: HOW_MANY.ALL,
        deliverTo: DELIVER_TO.RSS,
        //deliverToData: ''
    };
 
    alerts.create(alertToCreate, (err, alert) => {
	//console.log();
	//console.log(alerts);
//        console.log(alert);
//
	try {
//		console.log('trying');

		var alert_id = alert.id;
		alerts.sync( ()=> {
		//console.log(alert.id);
		alerts.getAlerts().forEach( al =>  {
			if(al.id == alert_id){
				console.log(al.rss);
			}
		});

		})	


	}
	catch {
//		console.log('err caught');
		alerts.getAlerts().forEach(al => {
			if(al.name.toLowerCase() == kw.toLowerCase()){
				console.log(al.rss);
			};
		});
	}
    });


});
