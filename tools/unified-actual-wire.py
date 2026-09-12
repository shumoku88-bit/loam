#!/usr/bin/env python3
"""Research-only unified Actual wire.

Project today's split admitted-shaped Actual evidence into one transaction-local
semantic stream. No current-codec re-expansion and no compatibility EffectKeys.
"""
from __future__ import annotations

import argparse, hashlib
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

MOVEMENT_MAGIC = "LOAM-MOVEMENT-MANIFEST\t2"
HEADERS = {
    "Event": "LOAM-EVENT-MEMORY\t1",
    "ActualValidity": "LOAM-ACTUAL-VALIDITY-HISTORY\t3",
    "EventDescription": "LOAM-EVENT-DESCRIPTION-MEMORY\t1",
    "RelationUnit": "LOAM-RELATION-UNIT-MEMORY\t1",
    "RelationDischarge": "LOAM-RELATION-DISCHARGE-MEMORY\t1",
}
CORRECTION_HEADER = "LOAM-EVENT-CORRECTION-MEMORY\t2"
REVERSAL_HEADER = "LOAM-ACTUAL-REVERSAL-MEMORY\t1"
UNIFIED_HEADER = "LOAM-UNIFIED-ACTUAL\t1"
REQUIRED = tuple(HEADERS)

class Error(RuntimeError): pass

@dataclass(frozen=True, order=True)
class Effect:
    key: str | None
    locus: str
    measure: str
    quanta: int

@dataclass(frozen=True, order=True)
class DateRevision:
    id: str
    valid_on: str
    predecessor_kind: str
    predecessor: str

@dataclass(frozen=True, order=True)
class Relation:
    id: str
    source_key: str
    debtor_kind: str
    debtor_token: str
    creditor_kind: str
    creditor_token: str
    quanta: int

@dataclass(frozen=True, order=True)
class Discharge:
    relation_id: str
    quanta: int

@dataclass(frozen=True)
class Tx:
    event: str
    base_date: str
    description: str | None
    replaces: str | None
    reversal_of: str | None
    effects: tuple[Effect, ...]
    revisions: tuple[DateRevision, ...]
    relations: tuple[Relation, ...]
    discharges: tuple[Discharge, ...]

@dataclass(frozen=True)
class Model:
    txs: tuple[Tx, ...]

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def payload(data: bytes, header: str, label: str) -> list[str]:
    try: text = data.decode("utf-8")
    except UnicodeDecodeError as exc: raise Error(f"{label}: not UTF-8") from exc
    if not text.endswith("\n"): raise Error(f"{label}: missing trailing newline")
    rows = text.splitlines()
    if not rows or rows[0] != header: raise Error(f"{label}: unsupported header")
    return rows[1:]

def unescape(text: str) -> str:
    out, i = [], 0
    table = {"\\": "\\", "n": "\n", "r": "\r", "t": "\t"}
    while i < len(text):
        if text[i] != "\\": out.append(text[i]); i += 1; continue
        if i + 1 >= len(text) or text[i + 1] not in table: raise Error("description: invalid escape")
        out.append(table[text[i + 1]]); i += 2
    return "".join(out)

def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")

def selected(root: Path) -> dict[str, bytes]:
    current = root / "movement-authority" / "CURRENT"
    if not current.is_file(): raise Error(f"missing selector: {current}")
    rows = current.read_text(encoding="utf-8").splitlines()
    if not rows or rows[0] != MOVEMENT_MAGIC: raise Error("unsupported Movement manifest")
    result: dict[str, bytes] = {}
    for row in rows[1:]:
        if not row: continue
        fields = row.split("\t")
        if len(fields) != 3: raise Error(f"malformed selector row: {row!r}")
        family, relative, expected = fields
        rel = Path(relative)
        if rel.is_absolute() or ".." in rel.parts: raise Error("unsafe selected path")
        path = root / "movement-authority" / rel
        if not path.is_file(): raise Error(f"missing selected object: {path}")
        data = path.read_bytes()
        if digest(data) != expected: raise Error(f"digest mismatch: {family}")
        if family in result: raise Error(f"duplicate selected family: {family}")
        result[family] = data
    missing = set(REQUIRED) - set(result)
    if missing: raise Error(f"missing selected family/families: {sorted(missing)}")
    return result

def parse_events(data: bytes) -> dict[str, list[tuple[str,str,str,int]]]:
    result: dict[str, list[tuple[str,str,str,int]]] = {}
    current: str | None = None
    keys: set[str] = set()
    for row in payload(data, HEADERS["Event"], "Event"):
        f = row.split("\t")
        if len(f) == 2 and f[0] == "EVENT":
            current = f[1]
            if not current or current in result: raise Error("Event: duplicate/empty EventId")
            result[current], keys = [], set()
        elif len(f) == 5 and f[0] == "EFFECT":
            if current is None: raise Error("Event: EFFECT before EVENT")
            _, key, locus, measure, qtext = f
            if not key or key in keys or not locus or not measure: raise Error("Event: invalid Effect")
            try: q = int(qtext)
            except ValueError as exc: raise Error("Event: invalid quantity") from exc
            keys.add(key); result[current].append((key,locus,measure,q))
        else: raise Error(f"Event: malformed row {row!r}")
    return result

def parse_validity(data: bytes):
    base: dict[str,str] = {}; revisions: dict[str,tuple[str,str]] = {}; pred: dict[str,tuple[str,str]] = {}
    for row in payload(data, HEADERS["ActualValidity"], "ActualValidity"):
        f = row.split("\t")
        if len(f) == 3 and f[0] == "BASE":
            if not f[1] or f[1] in base: raise Error("ActualValidity: duplicate BASE")
            base[f[1]] = f[2]
        elif len(f) == 4 and f[0] == "REVISION":
            if not f[1] or f[1] in revisions: raise Error("ActualValidity: duplicate revision")
            revisions[f[1]] = (f[2], f[3])
        elif len(f) == 4 and f[0] == "CORRECTION" and f[1] in ("ROOT","REVISION"):
            if f[3] in pred: raise Error("ActualValidity: replacement has multiple predecessors")
            pred[f[3]] = (f[1], f[2])
        else: raise Error(f"ActualValidity: malformed row {row!r}")
    if set(revisions) != set(pred): raise Error("ActualValidity: each revision must have one predecessor")
    for rid,(kind,target) in pred.items():
        event,_ = revisions[rid]
        if kind == "ROOT":
            if target != event or target not in base: raise Error("ActualValidity: bad ROOT predecessor")
        elif target not in revisions or revisions[target][0] != event:
            raise Error("ActualValidity: bad REVISION predecessor")
    return base,revisions,pred

def parse_descriptions(data: bytes) -> dict[str,str]:
    result = {}
    for row in payload(data, HEADERS["EventDescription"], "EventDescription"):
        f = row.split("\t",2)
        if len(f) != 3 or f[0] != "DESC" or not f[1] or f[1] in result: raise Error("EventDescription: malformed/duplicate row")
        result[f[1]] = unescape(f[2])
    return result

def parse_relations(data: bytes):
    result=[]; ids=set()
    for row in payload(data, HEADERS["RelationUnit"], "RelationUnit"):
        if not row: continue
        f=row.split("\t")
        if len(f)!=9 or f[0]!="RELATION": raise Error("RelationUnit: malformed row")
        _,rid,event,key,dk,dt,ck,ct,qtext=f
        if not rid or rid in ids or not event or not key: raise Error("RelationUnit: bad identity")
        try:q=int(qtext)
        except ValueError as exc: raise Error("RelationUnit: bad quantity") from exc
        ids.add(rid); result.append((rid,event,key,dk,dt,ck,ct,q))
    return result

def parse_discharges(data: bytes):
    result=[]; pairs=set()
    for row in payload(data, HEADERS["RelationDischarge"], "RelationDischarge"):
        if not row: continue
        f=row.split("\t")
        if len(f)!=4 or f[0]!="DISCHARGE": raise Error("RelationDischarge: malformed row")
        pair=(f[1],f[2])
        if pair in pairs: raise Error("RelationDischarge: duplicate admitted pair")
        try:q=int(f[3])
        except ValueError as exc: raise Error("RelationDischarge: bad quantity") from exc
        pairs.add(pair); result.append((f[1],f[2],q))
    return result

def parse_corrections(path: Path):
    if not path.is_file(): return []
    result=[]; targets=set(); replacements=set()
    for row in payload(path.read_bytes(),CORRECTION_HEADER,"EventCorrection"):
        f=row.split("\t")
        if len(f)!=3 or f[0]!="CORRECTION": raise Error("EventCorrection: malformed row")
        if f[1] in targets or f[2] in replacements: raise Error("EventCorrection: branching/merging")
        targets.add(f[1]); replacements.add(f[2]); result.append((f[1],f[2]))
    return result

def parse_reversals(path: Path):
    if not path.is_file(): return []
    result=[]; targets=set(); inverses=set()
    for row in payload(path.read_bytes(),REVERSAL_HEADER,"ActualReversal"):
        if not row: continue
        f=row.split("\t")
        if len(f)!=3 or f[0]!="REVERSE": raise Error("ActualReversal: malformed row")
        if f[1] in targets or f[2] in inverses: raise Error("ActualReversal: non-functional relation")
        targets.add(f[1]); inverses.add(f[2]); result.append((f[1],f[2]))
    return result

def load_split(root: Path) -> Model:
    fam=selected(root)
    events=parse_events(fam["Event"]); base,revisions,pred=parse_validity(fam["ActualValidity"])
    desc=parse_descriptions(fam["EventDescription"]); raw_rel=parse_relations(fam["RelationUnit"]); raw_dis=parse_discharges(fam["RelationDischarge"])
    corrections=parse_corrections(root/"corrections.loam"); reversals=parse_reversals(root/"actual-reversals.loam")
    ids=set(events)
    if set(base)!=ids: raise Error("admitted unified Actual requires one base date per Event")
    if not set(desc)<=ids: raise Error("description names absent Event")
    by_replacement={}
    for target,replacement in corrections:
        if target not in ids or replacement not in ids: raise Error("EventCorrection names absent Event")
        by_replacement[replacement]=target
    by_inverse={}
    for target,inverse in reversals:
        if target not in ids or inverse not in ids: raise Error("ActualReversal names absent Event")
        by_inverse[inverse]=target
    source_coords=set(); rel_by_event=defaultdict(list); rel_ids=set()
    for rid,event,key,dk,dt,ck,ct,q in raw_rel:
        if rid in rel_ids: raise Error("duplicate RelationUnit id")
        if event not in events or not any(k==key for k,*_ in events[event]): raise Error("RelationUnit source does not resolve")
        rel_ids.add(rid); source_coords.add((event,key)); rel_by_event[event].append(Relation(rid,key,dk,dt,ck,ct,q))
    dis_by_event=defaultdict(list)
    for event,rid,q in raw_dis:
        if event not in ids or rid not in rel_ids: raise Error("RelationDischarge target missing")
        dis_by_event[event].append(Discharge(rid,q))
    rev_by_event=defaultdict(list)
    for rid,(event,date) in revisions.items():
        kind,target=pred[rid]; rev_by_event[event].append(DateRevision(rid,date,kind,target))
    txs=[]
    for event,rows in events.items():
        effects=tuple(Effect(key if (event,key) in source_coords else None,locus,measure,q) for key,locus,measure,q in rows)
        txs.append(Tx(event,base[event],desc.get(event),by_replacement.get(event),by_inverse.get(event),effects,tuple(sorted(rev_by_event[event])),tuple(sorted(rel_by_event[event])),tuple(sorted(dis_by_event[event]))))
    model=Model(tuple(txs)); validate(model); return model

def encode(model: Model) -> bytes:
    rows=[UNIFIED_HEADER]
    for tx in model.txs:
        rows.append(f"TX\t{tx.event}\t{tx.base_date}\tNODESC" if tx.description is None else f"TX\t{tx.event}\t{tx.base_date}\tDESC\t{escape(tx.description)}")
        if tx.replaces is not None: rows.append(f"REPLACES\t{tx.replaces}")
        if tx.reversal_of is not None: rows.append(f"REVERSAL-OF\t{tx.reversal_of}")
        for e in tx.effects:
            rows.append(f"EFFECT\t{e.locus}\t{e.measure}\t{e.quanta}" if e.key is None else f"KEYED-EFFECT\t{e.key}\t{e.locus}\t{e.measure}\t{e.quanta}")
        for r in tx.revisions: rows.append(f"DATE-REV\t{r.id}\t{r.valid_on}\t{r.predecessor_kind}\t{r.predecessor}")
        for r in tx.relations: rows.append("\t".join(["RELATION",r.id,"SOURCE",r.source_key,r.debtor_kind,r.debtor_token,r.creditor_kind,r.creditor_token,str(r.quanta)]))
        for d in tx.discharges: rows.append(f"DISCHARGE\t{d.relation_id}\t{d.quanta}")
        rows.append("ENDTX")
    return ("\n".join(rows)+"\n").encode()

def decode(data: bytes) -> Model:
    rows=payload(data,UNIFIED_HEADER,"UnifiedActual"); txs=[]; seen=set(); i=0
    while i<len(rows):
        f=rows[i].split("\t")
        if len(f)==4 and f[0]=="TX" and f[3]=="NODESC": event,date,desc=f[1],f[2],None
        elif len(f)==5 and f[0]=="TX" and f[3]=="DESC": event,date,desc=f[1],f[2],unescape(f[4])
        else: raise Error(f"UnifiedActual: expected TX, got {rows[i]!r}")
        if not event or event in seen: raise Error("UnifiedActual: duplicate/empty Event")
        seen.add(event); i+=1; replaces=None; reversal=None; effects=[]; revisions=[]; relations=[]; discharges=[]; keys=set(); relids=set()
        while i<len(rows) and rows[i]!="ENDTX":
            f=rows[i].split("\t"); tag=f[0] if f else ""
            if tag=="REPLACES" and len(f)==2 and replaces is None: replaces=f[1]
            elif tag=="REVERSAL-OF" and len(f)==2 and reversal is None: reversal=f[1]
            elif tag=="EFFECT" and len(f)==4:
                try:q=int(f[3])
                except ValueError as exc: raise Error("UnifiedActual: bad Effect quantity") from exc
                effects.append(Effect(None,f[1],f[2],q))
            elif tag=="KEYED-EFFECT" and len(f)==5:
                if not f[1] or f[1] in keys: raise Error("UnifiedActual: duplicate stable EffectKey")
                try:q=int(f[4])
                except ValueError as exc: raise Error("UnifiedActual: bad Effect quantity") from exc
                keys.add(f[1]); effects.append(Effect(f[1],f[2],f[3],q))
            elif tag=="DATE-REV" and len(f)==5 and f[3] in ("ROOT","REVISION"): revisions.append(DateRevision(f[1],f[2],f[3],f[4]))
            elif tag=="RELATION" and len(f)==9 and f[2]=="SOURCE":
                if not f[1] or f[1] in relids: raise Error("UnifiedActual: duplicate RelationUnit id in TX")
                try:q=int(f[8])
                except ValueError as exc: raise Error("UnifiedActual: bad Relation quantity") from exc
                relids.add(f[1]); relations.append(Relation(f[1],f[3],f[4],f[5],f[6],f[7],q))
            elif tag=="DISCHARGE" and len(f)==3:
                try:q=int(f[2])
                except ValueError as exc: raise Error("UnifiedActual: bad Discharge quantity") from exc
                discharges.append(Discharge(f[1],q))
            else: raise Error(f"UnifiedActual: malformed row {rows[i]!r}")
            i+=1
        if i>=len(rows): raise Error(f"UnifiedActual {event}: missing ENDTX")
        txs.append(Tx(event,date,desc,replaces,reversal,tuple(effects),tuple(sorted(revisions)),tuple(sorted(relations)),tuple(sorted(discharges)))); i+=1
    model=Model(tuple(txs)); validate(model); return model

def validate(model: Model) -> None:
    txs={t.event:t for t in model.txs}
    if len(txs)!=len(model.txs): raise Error("UnifiedActual: duplicate Event")
    corr_targets=set(); reversal_targets=set(); relation_ids=set(); revisions={}
    for tx in model.txs:
        if tx.replaces is not None:
            if tx.replaces not in txs or tx.replaces in corr_targets: raise Error("UnifiedActual: invalid/branching REPLACES")
            corr_targets.add(tx.replaces)
        if tx.reversal_of is not None:
            if tx.reversal_of not in txs or tx.reversal_of in reversal_targets: raise Error("UnifiedActual: invalid REVERSAL-OF")
            reversal_targets.add(tx.reversal_of)
        keys=[e.key for e in tx.effects if e.key is not None]
        if len(keys)!=len(set(keys)): raise Error("UnifiedActual: duplicate stable EffectKey")
        keyed=set(keys)
        for r in tx.relations:
            if r.id in relation_ids or r.source_key not in keyed: raise Error("UnifiedActual: Relation source/id invalid")
            relation_ids.add(r.id)
        for r in tx.revisions:
            if r.id in revisions: raise Error("UnifiedActual: duplicate revision id")
            revisions[r.id]=(tx.event,r)
    for tx in model.txs:
        seen_dis=set()
        for r in tx.revisions:
            if r.predecessor_kind=="ROOT":
                if r.predecessor!=tx.event: raise Error("UnifiedActual: bad ROOT predecessor")
            elif r.predecessor not in revisions or revisions[r.predecessor][0]!=tx.event: raise Error("UnifiedActual: bad revision predecessor")
        for d in tx.discharges:
            if d.relation_id not in relation_ids or d.relation_id in seen_dis: raise Error("UnifiedActual: bad/duplicate discharge target")
            seen_dis.add(d.relation_id)

def normal(model: Model) -> tuple:
    rows=[]
    for t in model.txs:
        rows.append((t.event,t.base_date,t.description,t.replaces,t.reversal_of,tuple(sorted(Counter(t.effects).items())),tuple(sorted(t.revisions)),tuple(sorted(t.relations)),tuple(sorted(t.discharges))))
    return tuple(sorted(rows))

def project(root: Path, output: Path) -> None:
    model=load_split(root); wire=encode(model); decoded=decode(wire)
    if normal(model)!=normal(decoded): raise Error("unified wire changed semantic normal form")
    output.parent.mkdir(parents=True,exist_ok=True); output.write_bytes(wire)
    fam=selected(root); split=sum(len(fam[n]) for n in REQUIRED)
    for p in (root/"corrections.loam",root/"actual-reversals.loam"):
        if p.is_file(): split+=p.stat().st_size
    keyed=sum(e.key is not None for t in model.txs for e in t.effects); keyless=sum(e.key is None for t in model.txs for e in t.effects)
    print(f"unified Actual: {len(model.txs)} transactions, {keyless} keyless Effects, {keyed} stable-key Effects; {split} -> {len(wire)} bytes")
    print("unified Actual semantic normal form round trip passed")

def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument("root",type=Path); ap.add_argument("output",type=Path); args=ap.parse_args()
    try: project(args.root,args.output); return 0
    except Error as exc: print(f"unified Actual experiment failed: {exc}"); return 2

if __name__=="__main__": raise SystemExit(main())
