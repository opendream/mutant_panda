Mutant Panda
============

Mutant Panda is an open source solution for asset uploading, processing (creating derived assets such as transcodings for videos, thumbnails where applicable, etc).

It is based on, as the name implies, Panda. Panda is strictly for video assets. Please see [pandastream.com](http://pandastream.com/) for more information.


How does Mutant Panda work?
===========================

1. Asset is uploaded to panda
2. It checks the file's mimetype and stores the file in the right category
3. Some categories (currently only video) they have their derived assests created by a worker process
4. A callback sent to your web application notifying the derived assets have been created (if applicable)


The Workers
===========
Mutant panda knows two workers, the queue_processor (for diverted_processing) and the notifier (making http callbacks to the clients).

merb -r bin/queue_processor.rb -p 5001 -e production
merb -r bin/notifier.rb -p 6001 -e production



The REST api
============

<pre>
name       : Information on the webservice
method     : GET
route      : "/", "/info.js"
params     : client, api_key
returns    : server information as json (good for
             testing authentication and connectivity).

name       : Creating a new empty asset
method     : GET
route      : "/new.js"
params     : client, api_key,
             success_url (user is redirected here on success),
             failure_url (and here on failure)
returns    : a string with the ID of an empty asset.
             use this ID when uploading, deleting or
             requesting information on a particular asset.

name       : Uploading a file to an asset
method     : POST
route      : "/upload/:id" (replace :id with the asset ID)
params     : client, api_key, file
retuns     : a redirect (307) to the success_url or
             failure url when supplied. otherwise an accepted
             (202) status is given on success or an error
             status (401, 403, 404, 406, 415, 417, 500) to
             reflect the error condition.
comment    : use enctype='multipart/form-data' in html forms

name       : Requesting information on an asset
method     : GET
route      : "/assets/:id.js" (replace :id with the asset ID)
params     : client, api_key
returns    : the information on this asset as json string (200) 
             or an error status (401, 404) and a json string
             reflecting the error condition.

name       : Deleting an asset
method     : DELETE
route      : "/assets/:id.js" (replace :id with the asset ID)
params     : client, api_key
returns    : on success {'deleted': id} as a json string (200) 
             or an error status (401, 404) and a json string
             reflecting the error condition.

name       : A simple form for testing purpose only!
method     : GET
route      : /form.html
params     : client, api_key, id
return     : a super minimal upload form in invalid html
comment    : for testing only!
</pre>
