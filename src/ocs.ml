open Core

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
    rss: string;
  }

type config =
  { md_dir: string;
    template_dir: string;
    output_dir: string;
    use_pandoc: bool;
    single_file: string option;
    index_only: bool;
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

let find_with_prefix headers prefix =
  Option.(
    List.find headers ~f:(String.is_prefix ~prefix:prefix)
    >>= (String.chop_prefix ~prefix:prefix)
    |> value ~default:""
  )

let read_header contents =
  let headers = List.take_while contents ~f:((<>) "") in
  let (_, body) = List.split_n contents (List.length headers) in
  let title = find_with_prefix headers "title: " in
  let date = find_with_prefix headers "date: " in
  (title, parse_date date, (String.concat ~sep:"\n" body))

let md_to_post_using_omd md_dir path =
  let content_lines = In_channel.read_lines (Filename.concat md_dir path) in
  let (title, date, contents) = read_header content_lines in
  let html = Omd.to_html (Omd.of_string contents) in
  let html_path = String.chop_suffix_exn path ~suffix:".mdown" ^ ".html" in
  { path; contents; html; title; html_path ; date}

let md_to_post_using_pandoc md_dir path =
  let content_lines = In_channel.read_lines (Filename.concat md_dir path) in
  let (title, date, contents) = read_header content_lines in
  let md_path = Filename.concat md_dir path in
  let html_path = String.chop_suffix_exn path ~suffix:".mdown" ^ ".html" in
  (* do something with exit code *)
  let _ = Sys.command ("pandoc -f markdown -t html -o " ^ html_path ^ " " ^ md_path) in
  let html = In_channel.read_all html_path in
  { path; contents; html; title; html_path ; date}

let md_to_post md_dir use_pandoc path =
  if use_pandoc
  then md_to_post_using_pandoc md_dir path
  else md_to_post_using_omd md_dir path

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
  if not(config.index_only)
  then List.iter site.posts ~f:write_html
  else ();
  Out_channel.write_all (Filename.concat config.output_dir "index.html") ~data:site.index;
  Out_channel.write_all (Filename.concat config.output_dir "rss.xml") ~data:site.rss

let build_site config =
  let template_path = Filename.concat config.template_dir "post.html" in
  let template = In_channel.read_all template_path in
  let index_template_path = Filename.concat config.template_dir "index.html" in
  let post_paths = match config.single_file with
  | None -> search_for_mds config.md_dir
  | Some file -> [file] in
  { post_paths; template; posts = []; index_template_path; index = ""; rss = "" }

let build_index posts index_template_path =
  let posts = Ezjsonm.dict [ ("posts", Ezjsonm.list tobj_of_post posts) ] in
  let tmpl = In_channel.read_all index_template_path in
  Mustache.render (Mustache.of_string tmpl) (posts)

let base_url = "https://blog.ngzhian.com/"
let url_of_string s = Neturl.url_of_string Neturl.ip_url_syntax s

let build_rss posts =
  let get_date post = Netdate.create (fst (Unix.mktime post.date)) in
  let item post =
    let link = url_of_string (base_url ^ post.html_path) in
    Rss.(item ~title:post.title ~pubdate:(get_date post) ~link:link ~guid:(Guid_permalink link) ()) in
  let items = List.map posts item in
  let feed = Rss.(
    channel ~title:"Blog" ~desc:"blog" ~link:(url_of_string base_url) items
  ) in
  let _ = Rss.print_channel ~indent:2 (Format.str_formatter) feed in
  let rss = Format.flush_str_formatter () in
  rss

let compare_date p1 p2 = -(int_of_float (Unix.timegm p1.date -. Unix.timegm p2.date))
let convert config site =
  let posts =
    site.post_paths
    |> List.map ~f:(md_to_post config.md_dir config.use_pandoc)
    |> List.map ~f:(apply_template site.template)
    |> List.sort ~cmp:compare_date in
  let index = build_index posts site.index_template_path in
  let rss = build_rss posts in
  { { { site with posts } with index } with rss }

let generate config =
  build_site config
  |> convert config
  |> write config

let default_config =
  { md_dir = "."
  ; output_dir = "."
  ; template_dir = Filename.concat "." "template"
  ; use_pandoc = false
  ; single_file = None
  ; index_only = false
  }

let generate_default () =
  generate default_config

let generate_with_dir md_dir template_dir output_dir use_pandoc single_file index_only () =
  generate { md_dir ; output_dir ; template_dir; use_pandoc; single_file; index_only }

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
      +> flag "-p" (optional_with_default false bool) ~doc:"use pandoc"
      +> flag "-f" (optional string ) ~doc:"only parse one file"
      +> flag "-i" (optional_with_default false bool) ~doc:"index only"
    )
    generate_with_dir
)
