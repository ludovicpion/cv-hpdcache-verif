// ----------------------------------------------------------------------------
//Copyright 2024 CEA*
//*Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//[END OF HEADER]
// ----------------------------------------------------------------------------
//  Description : This tests random access to the HPDCACHE
// ----------------------------------------------------------------------------

`ifndef __test_hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp_SVH__
`define __test_hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp_SVH__

class test_hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp extends test_base;

  `uvm_component_utils(test_hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp)
  hpdcache_same_tag_set_access_request_cached m_seq[NREQUESTERS-1];
  int cnt;
  int num_expected_write = 0;

// -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_type_override_by_type(hpdcache_conf_txn::get_type() , hpdcache_conf_random_threshold_reset_timecnt::get_type());
    set_type_override_by_type(hpdcache_txn::get_type()      , hpdcache_zero_delay_cacheable_store_txn::get_type());
    set_type_override_by_type(hpdcache_top_cfg::get_type()  , hpdcache_top_one_requester_congestion_cfg::get_type());
  endfunction: new
  function void start_of_simulation_phase(uvm_phase phase);

    super.start_of_simulation_phase(phase);
    env.m_mem_rsp_model.set_enable_rd_output(0);
    env.m_mem_rsp_model.set_enable_wr_output(0);
  endfunction 

  // -------------------------------------------------------------------------
  // Pre Main Phase
  // -------------------------------------------------------------------------
  virtual task pre_main_phase(uvm_phase phase);
    // Create new sequence
    cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);

    for (int i = 0; i < NREQUESTERS-1; i++) begin
      m_seq[i] = hpdcache_same_tag_set_access_request_cached::type_id::create($sformatf("seq_%0d", i));
      if(!$cast(base_sequence[i], m_seq[i])) `uvm_fatal("CAST FAILED", "cannot cast base seqence");
      m_seq[i].wr_cnt_per_itr = cnt;       
    end

    super.pre_main_phase(phase);

  endtask: pre_main_phase


  virtual task main_phase(uvm_phase phase);
    int set = 0; 
    int num_rtab_entry;
 
    num_rtab_entry = 0; 
    num_rtab_entry = (env.m_hpdcache_conf.m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );

    if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin
      case(env.m_hpdcache_conf.m_cfg_wbuf_threshold) inside
       0:          num_expected_write =  (cnt == 1) ? HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry: 2 + num_rtab_entry; 
       default:    num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry; 
      endcase
    end else begin
      case(env.m_hpdcache_conf.m_cfg_wbuf_threshold) inside
        0: 
        begin
          num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;
        end 
        default: 
        begin
          num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES; 
        end
      endcase
      num_expected_write =  num_expected_write + ((env.m_hpdcache_conf.m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES)); 
    end

    fork 
    begin
      phase.raise_objection(this);

      vif.wait_n_clocks(HPDCACHE_WBUF_DIR_ENTRIES*cnt+HPDCACHE_RTAB_ENTRIES+500);

      if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin
        if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin

           num_expected_write = (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1 +  num_rtab_entry;

           if(env.m_hpdcache_sb.get_req_counter() == num_expected_write) begin
             `uvm_info("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                                  cnt, 
                                                                                  env.m_hpdcache_sb.get_req_counter(),
                                                                                  num_expected_write, 
                                                                                  num_rtab_entry, 
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                                  ), UVM_LOW);
           end else begin
             `uvm_error("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                                  cnt, 
                                                                                  env.m_hpdcache_sb.get_req_counter(),
                                                                                  num_expected_write,
                                                                                  num_rtab_entry, 
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                                  ));
           end
        end else begin
           if(env.m_hpdcache_sb.get_req_counter() == HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry) begin
             `uvm_info("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                                  cnt, 
                                                                                  env.m_hpdcache_sb.get_req_counter(),
                                                                                  ((cnt == 1)? HPDCACHE_WBUF_DIR_ENTRIES:1) +  num_rtab_entry,
                                                                                  num_rtab_entry, 
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                                  ), UVM_LOW);
           end else begin
             `uvm_error("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                                  cnt, 
                                                                                  env.m_hpdcache_sb.get_req_counter(),
                                                                                  num_expected_write,
                                                                                  num_rtab_entry, 
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                                  env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                                  ));
           end
        end
      end else begin
    
        // Depending on the pipeline we can some transactions accepted
        if(num_expected_write + 3 >  env.m_hpdcache_sb.get_req_counter() && env.m_hpdcache_sb.get_req_counter() >= num_expected_write)  begin
          `uvm_info("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                               cnt, 
                                                                               env.m_hpdcache_sb.get_req_counter(),
                                                                               num_expected_write,
                                                                               num_rtab_entry, 
                                                                               env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                               env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                               env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                               ), UVM_LOW);
        end else begin
          `uvm_error("TEST", $sformatf("Number of requests  txn count per itr=%0d(d) recieved %0d(d), expected %0d(d), RTAB ENTRIES %0d(d) THRESHOLD %0d(d), SEQ WAW=%0d(d) COALESCING %0x(x)", 
                                                                               cnt, 
                                                                               env.m_hpdcache_sb.get_req_counter(),
                                                                               num_expected_write,
                                                                               num_rtab_entry, 
                                                                               env.m_hpdcache_conf.m_cfg_wbuf_threshold,
                                                                               env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw,
                                                                               env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing
                                                                               ));
        end
      end
   
      env.m_mem_rsp_model.set_enable_rd_output(1);
      env.m_mem_rsp_model.set_enable_wr_output(1);

      phase.drop_objection(this);
    end 
    join_none

    super.main_phase(phase);

  endtask

endclass: test_hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp

`endif // __test_hpdcache_multiple_same_tag_set_store_random_threshold_reset_timecnt_with_memory_bp_SVH__