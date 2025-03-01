//  Copyright (c) 2011-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
// The following only applies to changes made to this file as part of YugaByte development.
//
// Portions Copyright (c) YugaByte, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License
// is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
// or implied.  See the License for the specific language governing permissions and limitations
// under the License.
//

#include <algorithm>
#include <map>
#include <string>

#include <gtest/gtest.h>

#include "yb/rocksdb/db/file_numbers.h"
#include "yb/rocksdb/db/filename.h"
#include "yb/rocksdb/db/flush_job.h"
#include "yb/rocksdb/db/version_set.h"
#include "yb/rocksdb/db/writebuffer.h"
#include "yb/rocksdb/table/mock_table.h"
#include "yb/rocksdb/util/file_reader_writer.h"
#include "yb/rocksdb/util/testharness.h"
#include "yb/rocksdb/util/testutil.h"

#include "yb/util/string_util.h"
#include "yb/util/test_macros.h"

namespace rocksdb {

// TODO(icanadi) Mock out everything else:
// 1. VersionSet
// 2. Memtable
class FlushJobTest : public RocksDBTest {
 public:
  FlushJobTest()
      : env_(Env::Default()),
        dbname_(test::TmpDir() + "/flush_job_test"),
        table_cache_(NewLRUCache(50000, 16)),
        write_buffer_(db_options_.db_write_buffer_size),
        versions_(new VersionSet(dbname_, &db_options_, env_options_,
                                 table_cache_.get(), &write_buffer_,
                                 &write_controller_)),
        shutting_down_(false),
        mock_table_factory_(new mock::MockTableFactory()) {
    EXPECT_OK(env_->CreateDirIfMissing(dbname_));
    db_options_.db_paths.emplace_back(dbname_,
                                      std::numeric_limits<uint64_t>::max());
    db_options_.boundary_extractor = test::MakeBoundaryValuesExtractor();
    // TODO(icanadi) Remove this once we mock out VersionSet
    NewDB();
    std::vector<ColumnFamilyDescriptor> column_families;
    cf_options_.table_factory = mock_table_factory_;
    column_families.emplace_back(kDefaultColumnFamilyName, cf_options_);

    EXPECT_OK(versions_->Recover(column_families, false));
  }

  void NewDB() {
    VersionEdit new_db;
    new_db.InitNewDB();

    const std::string manifest = DescriptorFileName(dbname_, 1);
    unique_ptr<WritableFile> file;
    Status s = env_->NewWritableFile(
        manifest, &file, env_->OptimizeForManifestWrite(env_options_));
    ASSERT_OK(s);
    unique_ptr<WritableFileWriter> file_writer(
        new WritableFileWriter(std::move(file), EnvOptions()));
    {
      log::Writer log(std::move(file_writer), 0, false);
      std::string record;
      new_db.AppendEncodedTo(&record);
      s = log.AddRecord(record);
    }
    ASSERT_OK(s);
    // Make "CURRENT" file that points to the new manifest file.
    s = SetCurrentFile(env_, dbname_, 1, nullptr, db_options_.disableDataSync);
  }

  Env* env_;
  std::string dbname_;
  EnvOptions env_options_;
  std::shared_ptr<Cache> table_cache_;
  WriteController write_controller_;
  DBOptions db_options_;
  WriteBuffer write_buffer_;
  ColumnFamilyOptions cf_options_;
  std::unique_ptr<VersionSet> versions_;
  InstrumentedMutex mutex_;
  std::atomic<bool> shutting_down_;
  std::atomic<bool> disable_flush_on_shutdown_{false};
  std::shared_ptr<mock::MockTableFactory> mock_table_factory_;
};

TEST_F(FlushJobTest, Empty) {
  JobContext job_context(0);
  auto cfd = versions_->GetColumnFamilySet()->GetDefault();
  EventLogger event_logger(db_options_.info_log.get());
  FileNumbersProvider file_numbers_provider(versions_.get());
  FlushJob flush_job(
      dbname_, versions_->GetColumnFamilySet()->GetDefault(), db_options_,
      *cfd->GetLatestMutableCFOptions(), env_options_, versions_.get(), &mutex_, &shutting_down_,
      &disable_flush_on_shutdown_, {}, kMaxSequenceNumber, MemTableFilter(), &file_numbers_provider,
      &job_context, nullptr, nullptr, nullptr, kNoCompression, nullptr, &event_logger);
  {
    InstrumentedMutexLock l(&mutex_);
    ASSERT_OK(yb::ResultToStatus(flush_job.Run()));
  }
  job_context.Clean();
}

TEST_F(FlushJobTest, NonEmpty) {
  JobContext job_context(0);
  auto cfd = versions_->GetColumnFamilySet()->GetDefault();
  auto new_mem = cfd->ConstructNewMemtable(*cfd->GetLatestMutableCFOptions(),
                                           kMaxSequenceNumber);
  new_mem->Ref();
  auto inserted_keys = mock::MakeMockFile();
  // Test data:
  //   seqno [    1,    2 ... 8998, 8999, 9000, 9001, 9002 ... 9999 ]
  //   key   [ 1001, 1002 ... 9998, 9999,    0,    1,    2 ...  999 ]
  // Expected:
  //   smallest_key   = "0"
  //   largest_key    = "9999"
  //   smallest_seqno = 1
  //   smallest_seqno = 9999

  test::BoundaryTestValues values;

  for (int i = 1; i < 10000; ++i) {
    std::string key(ToString((i + 1000) % 10000));
    std::string value("value" + key);
    Slice key_slice(key);
    Slice value_slice(value);
    new_mem->Add(
        SequenceNumber(i), kTypeValue, SliceParts(&key_slice, 1), SliceParts(&value_slice, 1));
    InternalKey internal_key(key, SequenceNumber(i), kTypeValue);
    inserted_keys.emplace(internal_key.Encode().ToBuffer(), value);
    values.Feed(key);
  }
  test::TestUserFrontiers frontiers(1, 12345);
  new_mem->UpdateFrontiers(frontiers);

  autovector<MemTable*> to_delete;
  cfd->imm()->Add(new_mem, &to_delete);
  for (auto& m : to_delete) {
    delete m;
  }

  EventLogger event_logger(db_options_.info_log.get());
  FileNumbersProvider file_numbers_provider(versions_.get());
  FlushJob flush_job(
      dbname_, versions_->GetColumnFamilySet()->GetDefault(), db_options_,
      *cfd->GetLatestMutableCFOptions(), env_options_, versions_.get(), &mutex_, &shutting_down_,
      &disable_flush_on_shutdown_, {}, kMaxSequenceNumber, MemTableFilter(), &file_numbers_provider,
      &job_context, nullptr, nullptr, nullptr, kNoCompression, nullptr, &event_logger);
  FileMetaData fd;
  {
    InstrumentedMutexLock l(&mutex_);
    ASSERT_OK(yb::ResultToStatus(flush_job.Run(&fd)));
  }
  ASSERT_EQ(ToString(0), fd.smallest.key.user_key().ToString());
  ASSERT_EQ(ToString(9999), fd.largest.key.user_key().ToString());
  ASSERT_EQ(1, fd.smallest.seqno);
  ASSERT_EQ(9999, fd.largest.seqno);
  ASSERT_TRUE(frontiers.Smallest().Equals(*fd.smallest.user_frontier));
  ASSERT_TRUE(frontiers.Largest().Equals(*fd.largest.user_frontier));
  values.Check(fd.smallest, fd.largest);
  mock_table_factory_->AssertSingleFile(inserted_keys);
  job_context.Clean();
}

TEST_F(FlushJobTest, Snapshots) {
  JobContext job_context(0);
  auto cfd = versions_->GetColumnFamilySet()->GetDefault();
  auto new_mem = cfd->ConstructNewMemtable(*cfd->GetLatestMutableCFOptions(),
                                           kMaxSequenceNumber);

  std::vector<SequenceNumber> snapshots;
  std::set<SequenceNumber> snapshots_set;
  int keys = 10000;
  int max_inserts_per_keys = 8;

  Random rnd(301);
  for (int i = 0; i < keys / 2; ++i) {
    snapshots.push_back(rnd.Uniform(keys * (max_inserts_per_keys / 2)) + 1);
    snapshots_set.insert(snapshots.back());
  }
  std::sort(snapshots.begin(), snapshots.end());

  new_mem->Ref();
  SequenceNumber current_seqno = 0;
  auto inserted_keys = mock::MakeMockFile();
  for (int i = 1; i < keys; ++i) {
    std::string key(ToString(i));
    Slice key_slice(key);
    int insertions = rnd.Uniform(max_inserts_per_keys);
    for (int j = 0; j < insertions; ++j) {
      std::string value(test::RandomHumanReadableString(&rnd, 10));
      Slice value_slice(value);
      auto seqno = ++current_seqno;
      new_mem->Add(SequenceNumber(seqno), kTypeValue, SliceParts(&key_slice, 1),
                   SliceParts(&value_slice, 1));
      // a key is visible only if:
      // 1. it's the last one written (j == insertions - 1)
      // 2. there's a snapshot pointing at it
      bool visible = (j == insertions - 1) ||
                     (snapshots_set.find(seqno) != snapshots_set.end());
      if (visible) {
        InternalKey internal_key(key, seqno, kTypeValue);
        inserted_keys.insert({internal_key.Encode().ToString(), value});
      }
    }
  }

  autovector<MemTable*> to_delete;
  cfd->imm()->Add(new_mem, &to_delete);
  for (auto& m : to_delete) {
    delete m;
  }

  EventLogger event_logger(db_options_.info_log.get());
  FileNumbersProvider file_numbers_provider(versions_.get());
  FlushJob flush_job(
      dbname_, versions_->GetColumnFamilySet()->GetDefault(), db_options_,
      *cfd->GetLatestMutableCFOptions(), env_options_, versions_.get(), &mutex_, &shutting_down_,
      &disable_flush_on_shutdown_, snapshots, kMaxSequenceNumber, MemTableFilter(),
      &file_numbers_provider, &job_context, nullptr, nullptr, nullptr, kNoCompression, nullptr,
      &event_logger);
  {
    InstrumentedMutexLock l(&mutex_);
    ASSERT_OK(yb::ResultToStatus(flush_job.Run()));
  }
  mock_table_factory_->AssertSingleFile(inserted_keys);
  job_context.Clean();
}

}  // namespace rocksdb

int main(int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
