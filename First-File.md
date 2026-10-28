# Install Neon skills to access my Neon project

npx neon@latest skills -s neon -s neon-postgres -y

pythonhex_color = "5038F5"
r = int(hex_color[0:2], 16)
g = int(hex_color[2:4], 16)
b = int(hex_color[4:6], 16)
print(f"R: {r}, G: {g}, B: {b}")
print(f"Normalized R: {r/255:.4f}, G: {g/255:.4f}, B: {b/255:.4f}")

Node 20 deprecation warning. actions/checkout@v4 and actions/setup-node@v4 are being force-run on Node 24. Works now, will break eventually. One-line fix to @v5 on both.

> > >

Sept 20, 2026 9:20pm
/swift-lead
Can you conduct an evaluation of the iOS app. I would like to prepare it for iOS 27. Please provide a detailed assessment of the current codebase, dependencies, and any potential issues that may arise with the new iOS version.

I created a markdown file to document the evaluation of the iOS app for iOS 27 compatibility: ios-27-evaluation.md. Make sure to also review security aspects, including authentication, data storage, and network communication > Auth is shared with the Web App.

The result of the evaluation is a phased plan outlining the necessary steps to ensure compatibility with iOS 27, including updates to dependencies, code modifications, and security enhancements. This plan will be executed by a downstream agent with work review by you.

# Duplicate Saved Location

iOS Duplicate Saved Location Issue.

- After a location is saved any edits/updates to the location creates a duplicate entry. These are identical except for the change. ie location id : 104 gets updated > on save > location 105 created with the updates. 104 is not altered.

- This is not to be conlfated with the same maps location as the same location ie; Statue of Liberty can be part of a saved location but for different events.

Please trace where this issue may be coming originating from. No Coding.

Remember API's are shared between iOS and Web, changes should be carefully considered to routes. I feel this is an iOS specific issue since I have not observed the same behavior on the Web app.

# iOS Add Photos to previously saved locations

Currently iOS does not allow added or updating data that is already not part of the saved location with the exception of a few standard fields.

- allow location editing to

> > >

Create a plan to allow iOS location edit/update to allow media management; setting a primary photo for the location, removing media, adding media and adding caption to the media.

Is it worth also planning a new workflow to the create-location button. I would like the user to be able to add captions in the process if they choose to; also allow more fields to be added during location creation.

> > Location Display

- for each location I would like to add a static map to the photo carousel. This is just a link that adds to a photo viewport the static map, rather than creating a snapshot and adding to media storage.

When a location is created with out media the fallback auto adds a static map.

Location Details UI a clickable icon to being user to the /map/location for the specific location.

> > iOS Login

\*\*\* Issue
When logging into iOS the map view shows behind the login sheet. It seems the app is already logged in but shows the logging screen regardless.

> > > Oct 12 2026

\*\*\* Issue user logging in
User on iOS recieved an error "Token Exchange Failed" handleAuthorizaionCodeGrant this tracks to the file attached. I logged in without issue.

Vercel Console:

2026-10-12 18:22:35.680 [error] [OAuth Token] Authorization code grant error: Error [PrismaClientKnownRequestError]:
Invalid `prisma.session.create()` invocation:

Unique constraint failed on the fields: (`token`)
at async I (.next/server/chunks/[root-of-the-server]**0bf20d3b.\_.js:1:3716)
at async u (.next/server/chunks/[root-of-the-server]**0bf20d3b._.js:1:9317)
at async d (.next/server/chunks/[root-of-the-server]\_\_0bf20d3b._.js:1:10358) {
code: 'P2002',
meta: [Object],
clientVersion: '6.19.3'
}
2026-10-12 18:22:35.680 [error] [OAuth Token] Error details: {
code: 'bb6rqx0hGJ9eZ1qIc85V6jod4mBV2ZfALfBoGhd-aYM',
client*id: 'fotolokashen-ios',
error: '\n' +
'Invalid `prisma.session.create()` invocation:\n' +
'\n' +
'\n' +
'Unique constraint failed on the fields: (`token`)',
stack: 'PrismaClientKnownRequestError: \n' +
'Invalid `prisma.session.create()` invocation:\n' +
'\n' +
'\n' +
'Unique constraint failed on the fields: (`token`)\n' +
' at ei.handleRequestError (/var/task/node_modules/@prisma/client/runtime/library.js:121:7268)\n' +
' at ei.handleAndLogRequestError (/var/task/node_modules/@prisma/client/runtime/library.js:121:6593)\n' +
' at ei.request (/var/task/node_modules/@prisma/client/runtime/library.js:121:6300)\n' +
' at async a (/var/task/node_modules/@prisma/client/runtime/library.js:130:9551)\n' +
' at async I (/var/task/.next/server/chunks/[root-of-the-server]\_\_0bf20d3b.*.js:1:3716)\n' +
' at async rW.do (/var/task/node*modules/next/dist/compiled/next-server/app-route-turbo.runtime.prod.js:5:20169)\n' +
' at async rW.handle (/var/task/node_modules/next/dist/compiled/next-server/app-route-turbo.runtime.prod.js:5:24949)\n' +
' at async u (/var/task/.next/server/chunks/[root-of-the-server]\_\_0bf20d3b.*.js:1:9317)\n' +
' at async rW.handleResponse (/var/task/node*modules/next/dist/compiled/next-server/app-route-turbo.runtime.prod.js:1:104211)\n' +
' at async d (/var/task/.next/server/chunks/[root-of-the-server]\_\_0bf20d3b.*.js:1:10358)'
}
