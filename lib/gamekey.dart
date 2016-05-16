import 'dart:convert';
import 'dart:io' ;
import 'package:start/start.dart';
import 'dart:math';
import 'dart:async';
import 'package:crypto/crypto.dart';


/*
class Gamekey{
    var storage;
    var port;
    var memory;
    var DB;

    Gamekey(){
    this.storage = "gamekey.json";
    this.port = 8080;
    this.DB = {
        service:    "Gamekey",
        storage:    SecureRandom.uuid,
        version:    "0.0.1",
        users:      [],
        games:      [],
        gamestates: []
    };
    File file = new File('/' + storage);
        if(file.existsSync()){

        }
}
}
*/


Map get_game_by_id(String id, Map memory) {
    for(Map m in memory['games']){
        if(m['id'].toString()==id.toString()) return m;
    }
    return null;
}

bool game_exists(String name, Map memory){
    for(Map m in memory['games']){
        if(m['name'] == name) return true;
    }
    return false;
}

Map get_user_by_name(String name, Map memory){
    for(Map m in memory['users']){
        if(m['name'] == name) return m;
    }
    //return null;
}

Map get_user_by_id(String id, Map memory){
    for(Map m in memory['users']){
        if(m['id'].toString() == id.toString()) return m;
    }
    //return null;
}

bool user_exists(String name, Map memory){
    for(Map m in memory['users']){
        if(m['name'] == name) return true;
    }
    return false;
}

bool isEmail(String em) {
    String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = new RegExp(p);
    return regExp.hasMatch(em);
}

bool isUrl(String url){
    String exp = '#\b(([\w-]+://?|www[.])[^\s()<>]+(?:\([\w\d]+\)|([^[:punct:]\s]|/)))#iS';
    RegExp regExp = new RegExp(exp);
    return regExp.hasMatch(url);
    //return true;
}

bool isAuthentic(Map user, String pwd){
    if(user['signature']!= BASE64.encode((sha256.convert(UTF8.encode(user["id"].toString() + ',' + pwd))).bytes))return true;
    return false;
}

main() async{
   // Gamekey test = new Gamekey();

    Map DB = {
        'service' : "Gamekey",
        //'storage':    SecureRandom.uuid,
        'version':    "0.0.1",
        'users':      [],
        'games':      [],
        'gamestates': []
    };
    Map memory ;
    File file = new File('\gamekey.json');
    //if(!await file.exists() || (await file.length() < DB.length)) {
        file.openWrite().write(JSON.encode(DB));
    //}
    memory = JSON.decode(await file.readAsString());
    start(port: 8080).then((Server app) {
        app.static('web');
        app.get('/users').listen((request){
            request.response.send(JSON.encode(memory["users"]));
        });

        app.post('/user').listen((request) async{
            //Control if payload can be used is missing
            var map = await request.payload();
            String name = map["name"];
            String pwd = map["pwd"];
            var mail = map["mail"];
            var id = new Random.secure().nextInt(0xFFFFFFFF);
            if(mail != null) {
                if (!isEmail(mail)) {
                    request.response.status(HttpStatus.BAD_REQUEST).send(
                        "Bad Request: $mail is not a valid email.");
                    return null;
                }
            }
            if(user_exists(name, memory)){
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Reqeust: The name $name is already taken");
                return null;
            }
            Digest test = (sha256.convert(UTF8.encode(id.toString() + ',' + pwd)));
            var user = {
            'type'       : "user",
            'name'       : name,
            'id'         : id.toString(),
            'created'    : (new DateTime.now().toIso8601String()),
            'mail'       : (mail != null)?mail:'',
            'signature'  : BASE64.encode(test.bytes)
            };
            memory["users"].add(user);
            file.openWrite().write(JSON.encode(memory));
            request.response.send(JSON.encode(user));
        });

        app.get('/user/:id').listen((request) async{
            Request req = await request;
            var id = req.param("id");
            var pwd = req.param("pwd");
            var byname = req.param("byname");
            //var pwd = "";
            //var byname = "";
            //print("hier du nutte");
            print(req.input.headers.contentLength);
            if(req.input.headers.contentLength != -1){
                var map = await req.payload();
                if(pwd.isEmpty)pwd = map["pwd"]==null?"":map["pwd"];
                if(byname.isEmpty)byname = map["byname"]==null?"":map["byname"];
            }
            print("ID:" + id + " PWD:" + pwd + " byname:" + byname);
            //    String pwd = map["pwd"];
            //String id = map["id"];
            //String byname = map["byname"];
            //print(await request.payload().whenComplete(print("hgri")));


            //print(await request.header);
            //print("Hallo" + pwd + id + byname);
            //print(jsonData.toString());

            Map user;
            if((!(byname.isEmpty) && (byname != 'true') && (byname != 'false')) || byname == 'wrong') {
                //print("bad");
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Request: byname parameter must be 'true' or 'false' (if set), was $byname.");
                return null;
            }
            if(byname == 'true'){
                //print("ich such nach name");
                user = get_user_by_name(id, memory);
            }
            if(byname == 'false' || byname.isEmpty) {
                //print("ich such nach id");
                user = get_user_by_id(id, memory);
            }
            if(user == null) {
                //print("notfound");
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "User not Found.");
                return null;
            }
            if(pwd == null){
                pwd = "";
            }
            if(isAuthentic(user,pwd)){
                //print("unauthorized");
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            user = new Map.from(user);
            if(memory['gamestate'] != null) {
                for (Map m in memory['gamestate']) {
                    if (m['userid'].toString() == id.toString()) {
                        user['games'].add(m['gameid']);
                    }
                }
            }
            else{
                user['games'] = new List();
            }
            request.response.status(HttpStatus.OK).send(JSON.encode(user));
        });

        app.put('/user/:id').listen((request) async{
            /* String id       = request.param('id');
            String pwd      = request.param('pwd');
            String new_name = request.param('name');
            String new_mail = request.param('mail');
            String new_pwd  = request.param('newpwd');
            print("ID:" + id + "PWD:" + pwd + "Name:" + new_name + "Mail:" + new_mail + "newPWD:" + new_pwd); */
            var map = await request.payload();
            String id       = request.param("id");
            String pwd      = map["pwd"]==null?"":map["pwd"];
            String new_name = map["name"]==null?"":map["name"];
            String new_mail = map["mail"]==null?"":map["mail"];
            String new_pwd  = map["newpwd"]==null?"":map["newpwd"];
            print("ID:" + id + "PWD:" + pwd + "Name:" + new_name + "Mail:" + new_mail + "newPWD:" + new_pwd);
            if(!isEmail(new_mail) && !new_mail.isEmpty){
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Request: $new_mail is not a valid email.");
                return null;
            }

            if(user_exists(new_name, memory)){
                request.response.status(HttpStatus.NOT_ACCEPTABLE).send("User with name $new_name exists already.");
                return null;
            }

            var user = get_user_by_id(id, memory);

            if(isAuthentic(user,pwd)){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(new_name != null)user['name'] = new_name;
            if(new_mail != null)user['mail'] = new_mail;
            if(new_pwd != null || !new_pwd.isEmpty)user['signature'] = BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + new_pwd.toString()))).bytes);
            user['update'] = new DateTime.now().toIso8601String();
            file.openWrite().write(JSON.encode(memory));

            //request.response.send('Succes\n$user');
            print(JSON.encode(user));
            request.response.status(HttpStatus.OK).send(JSON.encode(user));
        });

        app.delete('/user/:id').listen((request) async{
            var id = request.param('id');
            var pwd = request.param('pwd');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                pwd = map["pwd"] == null ? "" : map["pwd"];
            }

            var user = get_user_by_id(id, memory);

            if(user == null) {
                request.response.status(HttpStatus.OK).send(
                    "Userer not Found.");
                return null;
            }

            if(isAuthentic(user,pwd)){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(memory['users'].remove(user)==null){
                request.response.send('Failed\n$user');
            }
            file.openWrite().write(JSON.encode(memory));

            request.response.send('Succes\n$user');
        });

        app.get('/games').listen((request){
            request.response.send(JSON.encode(memory['games']));
        });

       app.post('/game').listen((request) async{
            String name   = request.param('name');
            var secret = request.param('secret');
            String url    = request.param('url');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(name.isEmpty)name = map["name"] == null ? "" : map["name"];
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
                if(url.isEmpty)url = map["url"] == null ? "" : map["url"];
            }
            var id = new Random.secure().nextInt(0xFFFFFFFF);
            if(name == null || name.isEmpty){
                request.response.send('Game must be given a name');
            }
            Uri uri = Uri.parse(url);
            if(uri != null || !url.isEmpty){
                if(uri.isAbsolute) {
                    request.response.send("Bad Request: '" + url +
                        "' is not a valid absolute url");
                    return null;
                }
            }
            //RegExp exp = new RegExp("http[s]?:.*.[A-Za-z1-9]+[.].*");
            if(!url.isEmpty && !isUrl(url)){
                request.response.send("Bad Request: '" + url + "' is not a valid absolute url");
                return null;
            }
            if(!memory['games'].isEmpty) {
                    if(game_exists(name,memory)){
                        request.response.status(HttpStatus.BAD_REQUEST).send(
                            "Game Already exists");
                        return null;
                    }
            }
            Map game = {
            "type"      : 'game',
            "name"      : name,
            "id"        : id.toString(),
            "url"       : uri.toString(),
            "signature" : BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString()))).bytes),
            "created"   : new DateTime.now().toIso8601String()
            };
            memory['games'].add(game);
            file.openWrite().write(JSON.encode(memory));
            request.response.send(JSON.encode(game));
        });
        
        app.get('/game/:id').listen((request) async{
            var secret = request.param('secret');
            var id = request.param('id');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
            }
            var game = get_game_by_id(id,memory);
            if(game == null){
                request.response.send("Game not found");
                return null;
            }
            game = new Map.from(game);
            if(BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString()))).bytes) != game['signature']){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            if(memory['gamestate'] != null) {
                for (Map m in memory['gamestate']) {
                    if (m['gameid'].toString() == id.toString()) {
                        game['users'].add(m['userid']);
                    }
                }
            }
            else{
                game['users'] = new List();
            }
            request.response.send(JSON.encode(game));
        });

         app.put('/game/:id').listen((request) async{
            var id         = request.param('id');
            var secret     = request.param('secret');
            var new_name   = request.param('name');
            var new_url    = request.param('url');
            var new_secret = request.param('newsecret');
            if(request.input.headers.contentLength != -1) {
                var map = await request.payload();
                if(new_name.isEmpty)new_name = map["name"] == null ? "" : map["name"];
                if(secret.isEmpty)secret = map["secret"] == null ? "" : map["secret"];
                if(new_url.isEmpty)new_url = map["url"] == null ? "" : map["url"];
                if(new_secret.isEmpty)new_secret = map["newsecret"] == null ? "" : map["newsecret"];
            }
            Uri uri = Uri.parse(new_url);
            var game = get_game_by_id(id,memory);
            print(new_url.isEmpty);
            if(!new_url.isEmpty && (!isUrl(new_url) || !uri.isAbsolute)){
                request.response.status(HttpStatus.BAD_REQUEST).send("Bad Request: '" + new_url + "' is not a valid absolute url");
                return null;
            }
            if(new_name != null){
                if(game_exists(new_name,memory)){
                    request.response.status(HttpStatus.BAD_REQUEST).send(
                        "Game Already exists");
                    return null;
                }
            }
            if(BASE64.encode((sha256.convert(UTF8.encode(id.toString() + ',' + secret.toString()))).bytes) != game['signature'].toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            if(new_name != null)game['name'] = new_name;
            if(new_url != null)game['url'] = new_url;
            if(new_secret != null)game['signature'] = BASE64.encode(UTF8.encode(new_name + new_secret));
            game['update'] = new DateTime.now().toString();
            file.openWrite().write(JSON.encode(memory));
             request.response.status(HttpStatus.OK).send(JSON.encode(game));
        });

        app.delete('/game/:id').listen((request){
            var id = request.param('id');
            var secret = request.param('secret');

            var game = get_game_by_id(id, memory);

            if(game == null){
                request.response.send("Game not found");
                return null;
            }
            if(BASE64.encode(UTF8.encode(id + secret)).toString() != game['signature']){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            if(memory['games'].remove(game)==null){
                request.response.send('Failed\n$game');
            }
            file.openWrite().write(JSON.encode(memory));

            request.response.send('Succes\n$game');
        });

        app.get('/gamestate/:gameid/:userid').listen((request){
            var gameid = request.param('gameid');
            var userid = request.param('userid');
            var secret = request.param('secret');

            var game = get_game_by_id(gameid, memory);
            var user = get_user_by_id(userid, memory);

            if(user == null || game == null){
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "User or game NOT Found.");
                return null;
            }

            if(game['signature'] != BASE64.encode(UTF8.encode(gameid + secret)).toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            Map states;
                for(Map m in memory['gamestates']){
                    if(m['gameid'].toString() == gameid.toString() && m['userid'].toString() == userid.toString()){
                        states.addAll(m);
                    }
                }
            return states.toString();
        });

        app.get('/gamestate/:gameid').listen((request) {
            var gameid = request.param('gameid');
            var secret = request.param('secret');

            var game = get_game_by_id(gameid, memory);

            if(game == null){
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "Game NOT Found.");
                return null;
            }

            if(!game['signature'].toString() == (BASE64.encode(UTF8.encode(gameid + secret))).toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }
            Map states;
            for(Map m in memory['gamestates']){
                if(m['gameid'].toString() == gameid.toString()){
                    states.addAll(m);
                }
            }
            return states.toString();
        });

        app.post('/gamestate/:gameid').listen((request) {
            var gameid = request.param('gameid');
            var userid = request.param('userid');
            var secret = request.param('secret');
            var state  = request.param('state');

            var game   = get_game_by_id(gameid, memory);
            var user   = get_user_by_id(userid, memory);

            if(user == null || game == null){
                request.response.status(HttpStatus.NOT_FOUND).send(
                    "User or game NOT Found.");
                return null;
            }

            if(game['signature'].toString() != (BASE64.encode(UTF8.encode(gameid + secret))).toString()){
                request.response.status(HttpStatus.UNAUTHORIZED).send("unauthorized, please provide correct credentials");
                return null;
            }

            state = JSON.decode(state);

            if(state == null || state.toString().isEmpty){
                request.response.status(HttpStatus.BAD_REQUEST).send(
                    "Bad request: state must not be empty, was $state");
                return null;
            }

            try{
                Map gamestate={
                    "type"    : 'gamestate',
                    "gameid"  : gameid,
                    "userid"  : userid,
                    "created" : (new DateTime.now()).toString(),
                    "state"   : state
                };
                file.openWrite().write(JSON.encode(memory));
                request.response.send(JSON.encode(gamestate));
            }
            catch(e){
                print(e);
                request.response.status(HttpStatus.BAD_REQUEST).send('Bad request: state must be provided as valid JSON, was $state');
            }
        });
    });
}
