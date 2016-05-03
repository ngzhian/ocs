open Core.Std

type post =
  { path : string;
    contents: string;
    html: string;
    title: string;
    html_path: string;
    date: Unix.tm;
  }

type site =
  { post_paths : string list;
    posts : post list;
    template: string;
    index_template_path: string;
    index: string;
  }

type config =
  { md_dir: string;
    template_dir: string;
    output_dir: string;
  }

let is_md path =
  String.is_suffix path ~suffix:".mdown"

let search_for_mds md_dir =
  Sys.ls_dir md_dir
  |> List.filter ~f:is_md

let parse_date =
  Unix.strptime ~fmt:"%F"

let date_string t =
  Unix.strftime t "%F"

let read_header contents =
  let open Option in
  let headers = List.take_while contents ~f:((<>) "") in
  let (_, body) = List.split_n contents (List.length headers) in
  let find_with_prefix _prefix =
    List.find headers ~f:(String.is_prefix ~prefix:_prefix)
    >>= (String.chop_prefix ~prefix:_prefix)
    |> value ~default:"" in
  let title = find_with_prefix "Title: " in
  let date = find_with_prefix "Date: " in
  (title, parse_date date, (String.concat ~sep:"\n" body))

let md_to_post md_dir path =
  let content_lines = In_channel.read_lines (Filename.concat md_dir path) in
  let (title, date, contents) = read_header content_lines in
  let html = Omd.to_html (Omd.of_string contents) in
  let html_path = String.chop_suffix_exn path ~suffix:".mdown" ^ ".html" in
  { path; contents; html; title; html_path ; date}

let tobj_of_post post =
  let open Ezjsonm in
  dict [ ("content", string post.html)
       ; ("title", string post.title)
       ; ("html_path", string post.html_path)
       ; ("date", string (date_string post.date))]

let apply_template tmpl post =
  let html = Mustache.render (Mustache.of_string tmpl) (tobj_of_post post) in
  { post with html }

let make_output_folder output_dir =
  match Sys.file_exists output_dir with
  | `No -> Unix.mkdir output_dir
  | _ -> ()

let write config site =
  make_output_folder config.output_dir;
  let html_path post = Filename.concat config.output_dir post.html_path in
  let write_html post = Out_channel.write_all (html_path post) ~data:post.html in
  List.iter site.posts ~f:write_html;
  Out_channel.write_all (Filename.concat config.output_dir "index.html") ~data:site.index
  
let build_site config =
  let template_path = Filename.concat config.template_dir "post.html" in
  let template = In_channel.read_all template_path in
  let index_template_path = Filename.concat config.template_dir "index.html" in
  let post_paths = search_for_mds config.md_dir in
  { post_paths; template; posts = []; index_template_path; index = "" }

let build_index site =
  let compare_date p1 p2 = -(int_of_float (Unix.timegm p1.date -. Unix.timegm p2.date)) in
  let posts = List.sort ~cmp:compare_date site.posts in
  let _posts = Ezjsonm.dict [ ("posts", Ezjsonm.list tobj_of_post posts) ] in
  let tmpl = In_channel.read_all site.index_template_path in
  let index = Mustache.render (Mustache.of_string tmpl) (_posts) in
  { site with index }

let convert config site =
  let posts = 
    site.post_paths
    |> List.map ~f:(md_to_post config.md_dir)
    |> List.map ~f:(apply_template site.template) in
  { site with posts }
  |> build_index
  
let generate config =
  build_site config
  |> convert config
  |> write config

let default_config =
  { md_dir = "."
  ; output_dir = "."
  ; template_dir = Filename.concat "." "template"
  }

let generate_default () =
  generate default_config

let generate_with_dir md_dir template_dir output_dir () =
  generate { md_dir ; output_dir ; template_dir }

(**
 *  Command line interface to ocs.
 *)
let () =
  Command.run ~version:"1.0" (
    Command.basic 
    ~summary:"Generate a static blog from markdown"
    Command.Spec.(
      empty
      +> flag "-m" (optional_with_default (Filename.concat "." "posts") string) ~doc:"directory"
      +> flag "-t" (optional_with_default (Filename.concat "." "template") string) ~doc:"directory"
      +> flag "-o" (optional_with_default "." string) ~doc:"directory"
    )
    generate_with_dir
)
