const axios = require('axios');

let url = process.argv[1]
let basicAuthToken = Buffer.from(process.argv[2]).toString('base64');

axios.get(
    url,
    {
        headers: {
            'Content-Type' : 'application/json',
            'Authorization' : 'Basic ' + basicAuthToken
        }
    }
).then(
    res => {
        console.log("Got Result: ", res.data);
    }
)