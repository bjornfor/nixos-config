{ config, lib, pkgs, ... }:
 
let
  myDictDBs = with pkgs.dictdDBs; [ wiktionary wordnet ];
in
{
  # dictd can be used by tools like goldendict, gnome-dictionary.
  services.dictd = {
    enable = true;
    DBs = myDictDBs;
  };
 
  environment.systemPackages = with pkgs; [
    # Offline wordnet dictionary.
    # Global hotkey to lookup a word: Ctrl + Alt + W.
    artha

    # goldendict hotkey to lookup a word: Ctrl-c-c.
    # Dictionaries in goldendict must be manually configured:
    # 1. Go to "Edit -> Dictionaries -> DICTD servers" and add/enable the local
    #    dictd server (dict://localhost).
    #    Alternatively: Don't use dictd service and load the dict files
    #    directly. Go to "Edit -> Dictionaries -> Files" and add
    #    /run/current-system/sw/share/dictd.
    # 2. Go to Dictionaries tab ("Edit -> Dictionaries -> Dictionaries" -- yes,
    #    twice) and set desired dictionary order/priority.
    # 3. Optional: Add separate DICT server entries, each limited to a single
    #    database. (To list databases, `dict --host localhost --dbs`). Doing
    #    this makes it easier to see where each result comes from, since
    #    goldendict highlights the start of new dictionary result set more than
    #    multiple results within a dictionary. IOW, results from all
    #    services.dictd.DBs are not visually "squashed" together as much.
    # 4. Optional: Add hunspell dictionaries for catching spelling mistakes.
    #    Go to "Edit -> Dictionaries -> Morphology" and add
    #    "/run/current-system/sw/share/hunspell".
    goldendict
  ] ++ (with hunspellDicts; [ en-us ])
    ++ myDictDBs;
}
