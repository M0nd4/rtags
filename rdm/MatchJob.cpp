#include "MatchJob.h"
#include "Server.h"
#include "Log.h"
#include "RTags.h"
#include "Rdm.h"
#include "LevelDB.h"

MatchJob::MatchJob(const QByteArray& p, int i, QueryMessage::Type t, unsigned flags)
    : Job(i, WriteUnfiltered), partial(p), type(t), keyFlags(flags)
{
}

void MatchJob::run()
{
    LevelDB db;
    if (!db.open(Server::SymbolName, LevelDB::ReadOnly)) {
        finish();
        return;
    }

    const bool hasFilter = !pathFilters().isEmpty();

    QByteArray entry;
    leveldb::Iterator* it = db.db()->NewIterator(leveldb::ReadOptions());
    it->Seek(partial.constData());
    while (it->Valid()) {
        entry = QByteArray(it->key().data(), it->key().size());
        if (type == QueryMessage::ListSymbols) {
            if (partial.isEmpty() || entry.startsWith(partial)) {
                bool ok = true;
                if (hasFilter) {
                    ok = false;
                    const QSet<RTags::Location> locations = Rdm::readValue<QSet<RTags::Location> >(it);
                    foreach(const RTags::Location &loc, locations) {
                        if (filter(loc.path)) {
                            ok = true;
                            break;
                        }
                    }
                }
                if (ok)
                    write(entry);
            } else {
                break;
            }
        } else {
            const int cmp = strcmp(partial.constData(), entry.constData());
            if (!cmp) {
                const QSet<RTags::Location> locations = Rdm::readValue<QSet<RTags::Location> >(it);
                foreach (const RTags::Location &loc, locations) {
                    if (filter(loc.path))
                        write(loc.key(keyFlags));
                }
            } else if (cmp > 0) {
                break;
            }
        }
        it->Next();
    }
    delete it;
    finish();
}
